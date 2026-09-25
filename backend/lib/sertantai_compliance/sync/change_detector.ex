defmodule SertantaiCompliance.Sync.ChangeDetector do
  @moduledoc """
  Detects legal change that affects each organisation and records it as
  events in the change feed (`applicability_events`).

  A change is modelled as "law X was affected by law Y": a new amending or
  revoking law, with the effect that has on X. A revocation is the outcome of
  a revoking law, so there is one event type, `law_amended`, with a
  `change_type`:

    * `amended` — a new amending law (moderate, review within 60 days)
    * `part_revoked` — partly revoked or repealed (major, 30 days)
    * `revoked` — revoked, repealed or abolished in full (major, 30 days)

  and `new_law_available` for a law newly in the screening corpus (e.g. newly
  made) that the screener says applies to an org whose register doesn't yet
  have it (major when strong; moderate when probable or caveated).

  ## How

  Each run diffs legal_register against `LawChangeSnapshot` (the state seen
  at the previous run) for every watched law, i.e. every law in any org's
  register plus the screening corpus. It raises events for the orgs affected,
  then updates the snapshot. **The first run only records the baseline**, so
  a feed starts from go-live rather than replaying the register's history.
  Runs are idempotent: a change is raised once, because the snapshot moves on.

  Scheduled daily by `SertantaiCompliance.Sync.Workers.ChangeDetectionWorker`;
  run by hand with `mix changes.detect`.
  """

  alias SertantaiCompliance.Fitness.{ApplicabilityEvaluator, Benchmark, Screener}
  alias SertantaiCompliance.Repo
  alias SertantaiCompliance.Sync.{ApplicabilityEvent, OrgScreeningProfile}

  require Logger

  @review_due_days %{"major" => 30, "moderate" => 60, "minor" => 90}

  @type law_state :: %{
          law_name: String.t(),
          title: String.t() | nil,
          live: String.t() | nil,
          amended_by: [String.t()],
          rescinded_by: [String.t()],
          in_corpus: boolean()
        }

  @type change :: %{
          law_name: String.t(),
          title: String.t() | nil,
          live: String.t() | nil,
          effect: String.t() | nil,
          caused_by: [String.t()],
          new_in_corpus: boolean()
        }

  # Same corpus the screener evaluates (see Fitness.Screener).
  @watch_sql """
  SELECT l.name, l.title_en, l.live,
         coalesce(l.amended_by, '{}'), coalesce(l.rescinded_by, '{}'),
         coalesce(l.is_making = true AND l.country = 'uk'
          AND (l.live IS NULL OR (l.live NOT LIKE '%Revoked%' AND l.live NOT LIKE '%Repealed%'
                                  AND l.live NOT LIKE '%Abolished%')), false) AS in_corpus
  FROM legal_register l
  WHERE (l.is_making = true AND l.country = 'uk')
     OR l.name IN (SELECT law_name FROM org_applicabilities WHERE status = 'yes')
  """

  # ── Run ─────────────────────────────────────────────────────────

  @doc """
  Detect changes since the last run and record events.

  Options: `baseline: true` records the current state without raising events
  (also what happens on the very first run).

  Returns `{:ok, %{baseline: boolean, watched: n, changes: n, events: %{org_id => counts}}}`.
  """
  @spec run(keyword()) :: {:ok, map()}
  def run(opts \\ []) do
    current = load_current()
    snapshot = load_snapshot()

    if snapshot == %{} or opts[:baseline] do
      save_snapshot(current)
      Logger.info("[ChangeDetector] Baseline recorded for #{map_size(current)} laws")
      {:ok, %{baseline: true, watched: map_size(current), changes: 0, events: %{}}}
    else
      changes = diff(snapshot, current)
      events = record_events(changes)
      save_snapshot(current)

      Logger.info("[ChangeDetector] #{length(changes)} changed laws, events: #{inspect(events)}")

      {:ok,
       %{baseline: false, watched: map_size(current), changes: length(changes), events: events}}
    end
  end

  # ── Diff (pure) ─────────────────────────────────────────────────

  @doc """
  Compare the previous `snapshot` with `current` law states (both keyed by
  law name). Returns the laws that changed: an amending/revoking effect, or
  newly in the screening corpus.
  """
  @spec diff(%{String.t() => law_state()}, %{String.t() => law_state()}) :: [change()]
  def diff(snapshot, current) do
    current
    |> Map.values()
    |> Enum.map(&change(Map.get(snapshot, &1.law_name), &1))
    |> Enum.reject(&(is_nil(&1.effect) and not &1.new_in_corpus))
    |> Enum.sort_by(& &1.law_name)
  end

  defp change(prev, now) do
    new_amending = if prev, do: now.amended_by -- prev.amended_by, else: []
    new_rescinding = if prev, do: now.rescinded_by -- prev.rescinded_by, else: []

    %{
      law_name: now.law_name,
      title: now.title,
      live: now.live,
      effect: prev && effect(status(prev.live), status(now.live), new_amending, new_rescinding),
      caused_by: Enum.uniq(new_rescinding ++ new_amending),
      new_in_corpus: now.in_corpus and not (prev != nil and prev.in_corpus)
    }
  end

  defp effect(before, :revoked, _amending, _rescinding) when before != :revoked, do: "revoked"
  defp effect(:in_force, :part, _amending, _rescinding), do: "part_revoked"
  defp effect(_before, now, _amending, [_ | _]) when now != :revoked, do: "part_revoked"
  defp effect(_before, _now, [_ | _], _rescinding), do: "amended"
  defp effect(_before, _now, _amending, _rescinding), do: nil

  # legal_register.live: "✔ In force", "⭕ Part Revocation / Repeal",
  # "❌ Revoked / Repealed / Abolished". Check "Part" first: it also says Repeal.
  @doc false
  def status(live) when is_binary(live) do
    cond do
      live =~ "Part" -> :part
      live =~ ~r/Revoked|Repealed|Abolished/ -> :revoked
      true -> :in_force
    end
  end

  def status(_live), do: :in_force

  # ── Events ──────────────────────────────────────────────────────

  defp record_events([]), do: %{}

  defp record_events(changes) do
    %{yes_by_law: yes_by_law, laws_by_org: laws_by_org} = registers()

    amended =
      for %{effect: effect} = change when effect != nil <- changes,
          org_id <- Map.get(yes_by_law, change.law_name, []) do
        log_law_amended(org_id, change)
        {org_id, "law_amended"}
      end

    new_laws =
      changes
      |> Enum.filter(& &1.new_in_corpus)
      |> Enum.map(& &1.law_name)
      |> record_new_laws(laws_by_org)

    (amended ++ new_laws)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {org_id, events} -> {org_id, Enum.frequencies(events)} end)
  end

  defp record_new_laws([], _laws_by_org), do: []

  defp record_new_laws(names, laws_by_org) do
    wanted = MapSet.new(names)
    laws = Enum.filter(Screener.corpus(), &MapSet.member?(wanted, &1.name))

    for profile <- Ash.read!(OrgScreeningProfile),
        org_id = profile.organization_id,
        known = Map.get(laws_by_org, org_id, MapSet.new()),
        result <-
          Screener.screen(
            ApplicabilityEvaluator.profile_from_screening(Map.from_struct(profile)),
            laws
          ),
        result.applies and not MapSet.member?(known, result.law.name) do
      log_new_law(org_id, result)
      {org_id, "new_law_available"}
    end
  end

  defp log_law_amended(org_id, change) do
    materiality = if change.effect == "amended", do: "moderate", else: "major"

    # The law stays in the register; the reviewer decides what to do.
    log(org_id, change.law_name, "law_amended", {"yes", "yes"}, materiality, %{
      "title" => change.title,
      "change_type" => change.effect,
      "caused_by" => change.caused_by,
      "live_status" => change.live
    })
  end

  defp log_new_law(org_id, %{law: law} = result) do
    tier = Benchmark.tier(result.confidence)
    materiality = if tier == "strong" and result.caveats == [], do: "major", else: "moderate"

    log(org_id, law.name, "new_law_available", {nil, "unreviewed"}, materiality, %{
      "title" => law.title_en,
      "family" => law.family,
      "confidence" => Float.round(result.confidence, 3),
      "tier" => tier,
      "caveats" => result.caveats
    })
  end

  defp log(org_id, law_name, event, {status_before, status_after}, materiality, metadata) do
    {:ok, _} =
      ApplicabilityEvent.log(%{
        organization_id: org_id,
        law_name: law_name,
        event: event,
        actor: "sertantai",
        status_before: status_before,
        status_after: status_after,
        source: "change_detection",
        materiality: materiality,
        review_due_date: review_due_date(materiality),
        metadata: metadata
      })
  end

  defp review_due_date(materiality) do
    case Map.get(@review_due_days, materiality) do
      nil -> nil
      days -> Date.add(Date.utc_today(), days)
    end
  end

  # ── Data ────────────────────────────────────────────────────────

  defp load_current do
    %{rows: rows} = Repo.query!(@watch_sql)

    Map.new(rows, fn [name, title, live, amended_by, rescinded_by, in_corpus] ->
      {name,
       %{
         law_name: name,
         title: title,
         live: live,
         amended_by: amended_by,
         rescinded_by: rescinded_by,
         # NULL for laws with no is_making/country (register-only laws)
         in_corpus: in_corpus == true
       }}
    end)
  end

  defp load_snapshot do
    %{rows: rows} =
      Repo.query!(
        "SELECT law_name, live, amended_by, rescinded_by, in_corpus FROM law_change_snapshots"
      )

    Map.new(rows, fn [name, live, amended_by, rescinded_by, in_corpus] ->
      {name,
       %{
         law_name: name,
         title: nil,
         live: live,
         amended_by: amended_by || [],
         rescinded_by: rescinded_by || [],
         # NULL for laws with no is_making/country (register-only laws)
         in_corpus: in_corpus == true
       }}
    end)
  end

  defp save_snapshot(current) do
    current
    |> Map.values()
    |> Enum.chunk_every(1_000)
    |> Enum.each(fn chunk ->
      Repo.query!(
        """
        INSERT INTO law_change_snapshots (law_name, live, amended_by, rescinded_by, in_corpus, snapshot_at)
        SELECT t.law_name, t.live, t.amended_by::text[], t.rescinded_by::text[], t.in_corpus,
               now() AT TIME ZONE 'utc'
        FROM unnest($1::text[], $2::text[], $3::text[], $4::text[], $5::boolean[])
             AS t(law_name, live, amended_by, rescinded_by, in_corpus)
        ON CONFLICT (law_name) DO UPDATE SET
          live = EXCLUDED.live,
          amended_by = EXCLUDED.amended_by,
          rescinded_by = EXCLUDED.rescinded_by,
          in_corpus = EXCLUDED.in_corpus,
          snapshot_at = EXCLUDED.snapshot_at
        """,
        [
          Enum.map(chunk, & &1.law_name),
          Enum.map(chunk, & &1.live),
          Enum.map(chunk, &encode_array(&1.amended_by)),
          Enum.map(chunk, &encode_array(&1.rescinded_by)),
          Enum.map(chunk, & &1.in_corpus)
        ]
      )
    end)
  end

  # unnest can't take text[][] of ragged rows, so each array travels as a
  # Postgres array literal and is cast back with ::text[].
  defp encode_array(values) do
    inner =
      Enum.map_join(values, ",", fn v ->
        ~s(") <> String.replace(String.replace(v, "\\", "\\\\"), ~s("), ~s(\\")) <> ~s(")
      end)

    "{" <> inner <> "}"
  end

  defp registers do
    %{rows: rows} =
      Repo.query!("SELECT organization_id, law_name, status FROM org_applicabilities")

    rows =
      Enum.map(rows, fn [org_id, law_name, status] ->
        {Ecto.UUID.load!(org_id), law_name, status}
      end)

    %{
      yes_by_law:
        rows
        |> Enum.filter(fn {_org, _law, status} -> status == "yes" end)
        |> Enum.group_by(fn {_org, law, _} -> law end, fn {org, _law, _} -> org end),
      laws_by_org:
        rows
        |> Enum.group_by(fn {org, _law, _} -> org end, fn {_org, law, _} -> law end)
        |> Map.new(fn {org, laws} -> {org, MapSet.new(laws)} end)
    }
  end
end
