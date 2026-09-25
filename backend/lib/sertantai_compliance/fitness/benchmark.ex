defmodule SertantaiCompliance.Fitness.Benchmark do
  @moduledoc """
  Compares a screener run with an organisation's legacy legal register.

  The legacy register is a **reference, not ground truth**: it contains
  revoked laws and drift. Every disagreement is a finding, and each one is
  attributed to a probable cause on one of these sides:

    * `register` — the legacy register is likely wrong (revoked, non-UK)
    * `classification` — legal classifies the law as not Making, so the
      screener never evaluates it (a misclassification, or an amending or
      procedural law kept in the register)
    * `legal_data` — the law has no record in legal_register
    * `tree` — the expression tree can't express applicability properly (no
      tree, territory only, gated by generic or government codes, the
      `construction` word-sense error)
    * `profile_or_tree` — a specific tree condition isn't met; either the
      profile lacks a true fact or the tree asks for the wrong thing
    * `screener` — the register explicitly says No but the screener matches
    * `unknown` — the screener matches a law that isn't in the register: a
      gap in the legacy register or a screener over-match

  Causes are found by re-evaluating the law with "what-if" profiles (e.g.
  would it apply if the profile also had the generic codes?).
  """

  alias SertantaiCompliance.CSV
  alias SertantaiCompliance.Fitness.{ApplicabilityEvaluator, Screener}
  alias SertantaiCompliance.Repo

  # Material codes true of almost any organisation that gate applicability
  # in trees. No human would enter them in a profile (sertantai-legal#161).
  @generic_codes ~w(building land licence body_corporate person offence application
                    area authority public premises_occupier)

  # Government bodies. They should be parties to a law, not conditions on
  # whether it applies to a governed organisation.
  @government_codes ~w(secretary_of_state local_authority scottish_ministers welsh_ministers
                       enforcement_authority appropriate_authority competent_authority
                       local_planning_authority national_park_authority public_authority
                       public_body highway_authority harbour_authority licensing_authority
                       nature_conservation_body chief_inspector crown_service crown_application)

  # "construction" in trees is usually statutory construction (interpretation),
  # not building work.
  @construction_codes ~w(construction)

  @reference_headers ~w(law_name status source)

  @triage_headers ~w(law_name title family geo_extent agreement side cause detail
                     register_status register_source confidence tier matched_dimensions caveats)

  @type reference_row :: %{law_name: String.t(), status: String.t(), source: String.t()}

  # ── Reference (legacy register) snapshot ─────────────────────────

  @doc "Snapshot an org's legacy register from org_applicabilities."
  @spec snapshot_reference(String.t()) :: [reference_row()]
  def snapshot_reference(org_id) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT law_name, status, coalesce(source, '')
        FROM org_applicabilities
        WHERE organization_id = $1 AND status IN ('yes', 'no')
        ORDER BY law_name
        """,
        [Ecto.UUID.dump!(org_id)]
      )

    Enum.map(rows, fn [law_name, status, source] ->
      %{law_name: law_name, status: status, source: source}
    end)
  end

  @spec write_reference!([reference_row()], Path.t()) :: :ok
  def write_reference!(rows, path) do
    lines = Enum.map(rows, &[&1.law_name, &1.status, &1.source])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, CSV.dump_to_iodata([@reference_headers | lines]))
  end

  @spec read_reference!(Path.t()) :: [reference_row()]
  def read_reference!(path) do
    path
    |> File.read!()
    |> CSV.parse_string()
    |> Enum.map(fn [law_name, status, source] ->
      %{law_name: law_name, status: status, source: source}
    end)
  end

  # ── Run ─────────────────────────────────────────────────────────

  @doc """
  Screen `profile_map` (profile fields, as stored or as JSON) and compare
  with `reference`. Returns `%{rows: triage_rows, summary: summary}`.

  Options (all default to the live database): `:laws` (screening corpus),
  `:law_status` (current legal_register state per referenced law name) and
  `:vocabulary` (tree vocabulary for routing the profile).
  """
  @spec run([reference_row()], map(), keyword()) :: %{rows: [map()], summary: map()}
  def run(reference, profile_map, opts \\ []) do
    laws = Keyword.get_lazy(opts, :laws, &Screener.corpus/0)
    profile = ApplicabilityEvaluator.profile_from_screening(profile_map, opts[:vocabulary])
    screened = Screener.screen(profile, laws)

    ref_by_name = Map.new(reference, &{&1.law_name, &1})

    law_status =
      Keyword.get_lazy(opts, :law_status, fn -> law_status(Map.keys(ref_by_name)) end)

    rows =
      screened
      |> Enum.map(&classify_screened(&1, Map.get(ref_by_name, &1.law.name), profile))
      |> Enum.reject(&is_nil/1)

    screened_names = MapSet.new(screened, & &1.law.name)

    outside_corpus =
      reference
      |> Enum.reject(&MapSet.member?(screened_names, &1.law_name))
      |> Enum.map(&classify_outside_corpus(&1, Map.get(law_status, &1.law_name)))
      |> Enum.reject(&is_nil/1)

    rows = Enum.sort_by(rows ++ outside_corpus, &{&1.agreement, &1.side, &1.cause, &1.law_name})

    %{rows: rows, summary: summarise(rows, screened)}
  end

  # Laws in the screening corpus (in-force UK Making laws). Laws neither the
  # screener nor the register selects are left out.
  defp classify_screened(%{law: law} = s, ref, profile) do
    case agreement(s, ref, profile) do
      nil -> nil
      {agreement, side, cause, detail} -> row(law, s, ref, agreement, side, cause, detail)
    end
  end

  defp agreement(s, ref, profile) do
    register = ref && ref.status

    cond do
      s.applies and register == "yes" ->
        {"both", "", "", ""}

      s.applies and register == "no" ->
        {"screener_only", "screener", "register_says_no", ""}

      s.applies ->
        Tuple.insert_at(screener_only_cause(s), 0, "screener_only")

      register == "yes" ->
        Tuple.insert_at(register_only_cause(s.law, profile), 0, "register_only")

      register == "no" ->
        {"agree_no", "", "", ""}

      true ->
        nil
    end
  end

  # Referenced laws outside the corpus: revoked, not Making, non-UK or missing.
  defp classify_outside_corpus(%{status: "yes"} = ref, status) do
    {side, cause, detail} =
      case status do
        nil -> {"legal_data", "missing_record", "not in legal_register"}
        %{revoked: true} -> {"register", "revoked", status.live || ""}
        %{country: country} when country != "uk" -> {"register", "non_uk", country || ""}
        %{is_making: false} -> {"classification", "not_making", ""}
        _ -> {"legal_data", "outside_corpus", ""}
      end

    %{
      law_name: ref.law_name,
      title: (status && status.title_en) || "",
      family: (status && status.family) || "",
      geo_extent: (status && status.geo_extent) || "",
      agreement: "register_only",
      side: side,
      cause: cause,
      detail: detail,
      register_status: ref.status,
      register_source: ref.source,
      confidence: "",
      tier: "",
      matched_dimensions: "",
      caveats: ""
    }
  end

  defp classify_outside_corpus(_ref, _status), do: nil

  defp screener_only_cause(s) do
    tree_dims = tree_dimensions(s.law.compiled_applicability)
    matched_dims = s.reasons |> Enum.map(& &1.dimension) |> Enum.uniq()
    caveat_kinds = s.caveats |> Enum.map(& &1.kind) |> Enum.uniq()

    cond do
      "disapplication" in caveat_kinds ->
        {"tree", "soft_disapplication", format_caveats(s.caveats)}

      "time_window" in caveat_kinds ->
        {"tree", "time_window_caveat", format_caveats(s.caveats)}

      MapSet.subset?(tree_dims, MapSet.new(["territorial", "temporal"])) ->
        {"tree", "territory_only_tree", ""}

      matched_dims == ["territorial"] ->
        {"tree", "territory_branch_match",
         "tree has #{Enum.join(Enum.sort(tree_dims), "/")} but matched on territory"}

      true ->
        {"unknown", "register_gap_or_overmatch", matched_codes(s.reasons)}
    end
  end

  defp register_only_cause(%{compiled_applicability: nil}, _profile), do: {"tree", "no_tree", ""}

  defp register_only_cause(law, profile) do
    tree = law.compiled_applicability
    # Checked first: what-ifs add codes, which can take the org out of a
    # categorical exclusion and hide it.
    excluding = excluding_disapplications(tree, profile)

    cond do
      excluding != [] ->
        {"tree", "disapplied_by_not", "org wholly within Not: " <> Enum.join(excluding, " ")}

      applies_with?(tree, profile, "material", @generic_codes) ->
        {"tree", "generic_code_gate", ""}

      applies_with?(tree, profile, "personal", @government_codes) ->
        {"tree", "gov_actor_gate", ""}

      applies_with?(tree, profile, "material", @construction_codes) ->
        {"tree", "construction_misfire", "needs 'construction' (statutory interpretation sense)"}

      true ->
        condition_miss(tree, profile)
    end
  end

  # Which single dimension, filled with the tree's own codes, makes it apply?
  defp condition_miss(tree, profile) do
    codes_by_dim = positive_codes(tree)

    hit =
      Enum.find(["personal", "material", "territorial", "conditional"], fn dim ->
        codes = Map.get(codes_by_dim, dim, [])
        codes != [] and applies_with?(tree, profile, dim, codes)
      end)

    case hit do
      nil ->
        all_dims_condition_miss(tree, profile, codes_by_dim)

      dim ->
        missing = Map.get(codes_by_dim, dim, []) -- Map.get(profile, dim, [])

        {"profile_or_tree", "#{dim}_condition_miss",
         "needs one of: " <> (missing |> Enum.take(8) |> Enum.join(" "))}
    end
  end

  # No single dimension is enough: try all of the tree's codes together.
  # If even that fails, a Not (disapplies) or TimeWindow node blocks it.
  defp all_dims_condition_miss(tree, profile, codes_by_dim) do
    everything =
      Map.merge(profile, codes_by_dim, fn _dim, mine, theirs -> Enum.uniq(mine ++ theirs) end)

    detail = summarise_codes(codes_by_dim, profile)

    triggered_nots = triggered_negative_codes(tree, profile)

    cond do
      ApplicabilityEvaluator.evaluate(tree, everything).applies ->
        {"profile_or_tree", "multi_condition_miss", detail}

      triggered_nots != [] ->
        {"tree", "soft_disapplication_blocks",
         "profile triggers Not: " <> Enum.join(triggered_nots, " ")}

      has_op?(tree, "TimeWindow") ->
        {"tree", "outside_time_window", detail}

      true ->
        {"profile_or_tree", "unexplained", detail}
    end
  end

  defp applies_with?(tree, profile, dim, codes) do
    extended = Map.update(profile, dim, codes, &Enum.uniq(&1 ++ codes))
    ApplicabilityEvaluator.evaluate(tree, extended).applies
  end

  defp row(law, s, ref, agreement, side, cause, detail) do
    %{
      law_name: law.name,
      title: law.title_en || "",
      family: law.family || "",
      geo_extent: law.geo_extent || "",
      agreement: agreement,
      side: side,
      cause: cause,
      detail: detail,
      register_status: (ref && ref.status) || "",
      register_source: (ref && ref.source) || "",
      confidence: if(s.applies, do: Float.round(s.confidence, 3), else: ""),
      tier: if(s.applies, do: tier(s.confidence), else: ""),
      matched_dimensions:
        s.reasons |> Enum.map(& &1.dimension) |> Enum.uniq() |> Enum.sort() |> Enum.join("/"),
      caveats: format_caveats(s.caveats)
    }
  end

  defp format_caveats(caveats) do
    Enum.map_join(caveats, "; ", fn
      %{kind: "disapplication", dimension: dim, codes: codes} ->
        "may be disapplied: #{dim}:#{Enum.join(codes, ",")}"

      %{kind: "time_window", from: from, to: to} ->
        "time window #{from || "…"} to #{to || "…"}"
    end)
  end

  @doc "Confidence tier, using the same thresholds as the screening API."
  @spec tier(float()) :: String.t()
  def tier(confidence) when confidence >= 0.8, do: "strong"
  def tier(confidence) when confidence >= 0.5, do: "probable"
  def tier(_confidence), do: "possible"

  # ── Tree helpers ────────────────────────────────────────────────

  defp tree_dimensions(tree) do
    tree |> tree_codes() |> Map.keys() |> MapSet.new() |> add_temporal(tree)
  end

  defp add_temporal(dims, tree) do
    if has_op?(tree, "TimeWindow"), do: MapSet.put(dims, "temporal"), else: dims
  end

  defp has_op?(%{"op" => op}, op), do: true
  defp has_op?(%{"children" => children}, op), do: Enum.any?(children, &has_op?(&1, op))

  defp has_op?(%{"condition" => c, "then" => t}, op), do: has_op?(c, op) or has_op?(t, op)
  defp has_op?(%{"child" => child}, op), do: has_op?(child, op)
  defp has_op?(_, _), do: false

  @doc false
  @spec tree_codes(map() | nil) :: %{String.t() => [String.t()]}
  def tree_codes(tree) do
    tree
    |> collect_codes()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {dim, codes} -> {dim, Enum.uniq(codes)} end)
  end

  # Not nodes the evaluator treats as categorical exclusions for this
  # profile (the org is wholly within them); returns the triggering codes.
  defp excluding_disapplications(tree, profile) do
    tree
    |> not_nodes()
    |> Enum.map(&not_child/1)
    |> Enum.filter(fn child ->
      child != nil and ApplicabilityEvaluator.evaluate(child, profile).applies and
        ApplicabilityEvaluator.wholly_excluded?(child, profile)
    end)
    |> Enum.flat_map(fn child ->
      child
      |> collect_codes()
      |> Enum.filter(fn {dim, code} -> code in Map.get(profile, dim, []) end)
      |> Enum.map(fn {dim, code} -> "#{dim}:#{code}" end)
    end)
    |> Enum.uniq()
  end

  defp not_nodes(%{"op" => "Not"} = node), do: [node | not_nodes(not_child(node))]
  defp not_nodes(%{"children" => children}), do: Enum.flat_map(children, &not_nodes/1)
  defp not_nodes(%{"condition" => c, "then" => t}), do: not_nodes(c) ++ not_nodes(t)
  defp not_nodes(%{"inner" => inner}), do: not_nodes(inner)
  defp not_nodes(_), do: []

  # Codes outside Not (disapplies) subtrees: adding these can only help.
  defp positive_codes(tree) do
    tree
    |> collect_codes(:positive)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {dim, codes} -> {dim, Enum.uniq(codes)} end)
  end

  # Profile codes that match inside a Not subtree (the law is disapplied).
  defp triggered_negative_codes(tree, profile) do
    tree
    |> collect_codes(:negative)
    |> Enum.filter(fn {dim, code} -> code in Map.get(profile, dim, []) end)
    |> Enum.map(fn {dim, code} -> "#{dim}:#{code}" end)
    |> Enum.uniq()
  end

  defp collect_codes(%{"op" => "Not"}, :positive), do: []

  defp collect_codes(%{"op" => "Not"} = node, :negative), do: collect_codes(not_child(node))

  defp collect_codes(%{"children" => children}, mode),
    do: Enum.flat_map(children, &collect_codes(&1, mode))

  defp collect_codes(%{"condition" => c, "then" => t}, mode),
    do: collect_codes(c, mode) ++ collect_codes(t, mode)

  defp collect_codes(%{"op" => "Match", "dimension" => dim, "codes" => codes}, :positive),
    do: Enum.map(codes, &{dim, &1})

  defp collect_codes(_node, _mode), do: []

  defp not_child(%{"child" => child}), do: child
  defp not_child(%{"children" => [child | _]}), do: child
  defp not_child(_), do: nil

  defp collect_codes(%{"op" => "Match", "dimension" => dim, "codes" => codes}),
    do: Enum.map(codes, &{dim, &1})

  defp collect_codes(%{"children" => children}), do: Enum.flat_map(children, &collect_codes/1)

  defp collect_codes(%{"condition" => c, "then" => t}), do: collect_codes(c) ++ collect_codes(t)
  defp collect_codes(%{"child" => child}), do: collect_codes(child)
  defp collect_codes(_), do: []

  defp matched_codes(reasons) do
    reasons
    |> Enum.flat_map(fn r -> Enum.map(r.matched_codes, &"#{r.dimension}:#{&1}") end)
    |> Enum.uniq()
    |> Enum.take(8)
    |> Enum.join(" ")
  end

  defp summarise_codes(codes_by_dim, profile) do
    codes_by_dim
    |> Enum.map(fn {dim, codes} -> {dim, codes -- Map.get(profile, dim, [])} end)
    |> Enum.reject(fn {_dim, missing} -> missing == [] end)
    |> Enum.map_join("; ", fn {dim, missing} ->
      "#{dim}: " <> (missing |> Enum.take(5) |> Enum.join(" "))
    end)
  end

  # ── Current legal_register state for referenced laws ────────────

  defp law_status([]), do: %{}

  defp law_status(names) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT name, title_en, family, geo_extent, country, coalesce(is_making, false), live
        FROM legal_register
        WHERE name = ANY($1)
        """,
        [names]
      )

    Map.new(rows, fn [name, title, family, geo, country, is_making, live] ->
      {name,
       %{
         title_en: title,
         family: family,
         geo_extent: geo,
         country: country,
         is_making: is_making,
         live: live,
         revoked: is_binary(live) and live =~ ~r/Revoked|Repealed|Abolished/
       }}
    end)
  end

  # ── Summary ─────────────────────────────────────────────────────

  defp summarise(rows, screened) do
    count = fn pred -> Enum.count(rows, pred) end
    by_agreement = Enum.frequencies_by(rows, & &1.agreement)

    both = Map.get(by_agreement, "both", 0)

    register_only_evaluable =
      count.(&(&1.agreement == "register_only" and &1.side in ["tree", "profile_or_tree"]))

    hits = Enum.filter(rows, &(&1.tier != ""))

    %{
      corpus: %{
        laws: length(screened),
        with_trees: Enum.count(screened, &(&1.law.compiled_applicability != nil)),
        applies: Enum.count(screened, & &1.applies)
      },
      agreement: by_agreement,
      evaluable_agreement_rate: rate(both, both + register_only_evaluable),
      causes:
        rows
        |> Enum.reject(&(&1.cause == ""))
        |> Enum.frequencies_by(&{&1.agreement, &1.side, &1.cause})
        |> Enum.sort_by(fn {_k, n} -> -n end)
        |> Enum.map(fn {{agreement, side, cause}, n} ->
          %{agreement: agreement, side: side, cause: cause, laws: n}
        end),
      tiers:
        hits
        |> Enum.group_by(& &1.tier)
        |> Map.new(fn {tier, rs} ->
          in_register = Enum.count(rs, &(&1.agreement == "both"))
          {tier, %{applies: length(rs), in_register: in_register}}
        end),
      families: breakdown(rows, & &1.family),
      jurisdictions: breakdown(rows, & &1.geo_extent)
    }
  end

  defp breakdown(rows, key) do
    rows
    |> Enum.group_by(&(key.(&1) |> blank_to("(none)")))
    |> Enum.map(fn {k, rs} ->
      f = Enum.frequencies_by(rs, & &1.agreement)

      %{
        key: k,
        both: Map.get(f, "both", 0),
        register_only: Map.get(f, "register_only", 0),
        screener_only: Map.get(f, "screener_only", 0)
      }
    end)
    |> Enum.sort_by(&(-(&1.both + &1.register_only + &1.screener_only)))
  end

  defp blank_to(v, default) when v in [nil, ""], do: default
  defp blank_to(v, _default), do: v

  defp rate(_n, 0), do: 0.0
  defp rate(n, d), do: Float.round(n / d, 3)

  # ── Output ──────────────────────────────────────────────────────

  @doc "Write triage CSV, summary JSON and summary markdown into `dir`."
  @spec write!(%{rows: [map()], summary: map()}, Path.t(), map()) :: :ok
  def write!(%{rows: rows, summary: summary}, dir, meta) do
    File.mkdir_p!(dir)

    lines =
      Enum.map(rows, fn r ->
        Enum.map(@triage_headers, &to_string(Map.fetch!(r, String.to_atom(&1))))
      end)

    File.write!(
      Path.join(dir, "triage.csv"),
      CSV.dump_to_iodata([@triage_headers | lines])
    )

    File.write!(
      Path.join(dir, "summary.json"),
      Jason.encode!(Map.put(summary, :meta, meta), pretty: true)
    )

    File.write!(Path.join(dir, "summary.md"), markdown(summary, meta))
  end

  @doc "Markdown report for a run, with deltas against `meta.previous` if given."
  @spec markdown(map(), map()) :: String.t()
  def markdown(summary, meta) do
    prev = Map.get(meta, :previous)
    a = summary.agreement

    delta = fn path, value ->
      case prev && get_in(prev, path) do
        nil -> ""
        old when is_number(old) and old != value -> " (#{sign(value - old)})"
        _ -> ""
      end
    end

    agreement_rows =
      for k <- ~w(both register_only screener_only agree_no) do
        v = Map.get(a, k, 0)
        "| #{k} | #{v}#{delta.(["agreement", k], v)} |"
      end

    cause_rows =
      Enum.map(summary.causes, fn c ->
        "| #{c.agreement} | #{c.side} | #{c.cause} | #{c.laws} |"
      end)

    tier_rows =
      for t <- ~w(strong probable possible), tier = Map.get(summary.tiers, t) do
        "| #{t} | #{tier.applies} | #{tier.in_register} |"
      end

    family_rows =
      summary.families
      |> Enum.take(15)
      |> Enum.map(&"| #{&1.key} | #{&1.both} | #{&1.register_only} | #{&1.screener_only} |")

    rate = summary.evaluable_agreement_rate

    """
    # Screener benchmark: #{meta.name} (#{meta.label})

    Run #{meta.run_at}. Profile: #{meta.profile_source}. Reference: #{meta.reference}#{if prev, do: ". Compared with #{prev["meta"]["run_at"]}", else: ""}.

    The legacy register is a reference, not ground truth: each disagreement is triaged in `triage.csv`.

    **Corpus**: #{summary.corpus.laws} in-force UK Making laws, #{summary.corpus.with_trees} with trees; screener applies to #{summary.corpus.applies}#{delta.(["corpus", "applies"], summary.corpus.applies)}.

    **Evaluable agreement**: #{Float.round(rate * 100, 1)}%#{delta.(["evaluable_agreement_rate"], rate)} (in both, over in both + register-only laws the screener could evaluate).

    ## Agreement

    | Agreement | Laws |
    |---|---|
    #{Enum.join(agreement_rows, "\n")}

    ## Causes (ranked)

    | Agreement | Side | Cause | Laws |
    |---|---|---|---|
    #{Enum.join(cause_rows, "\n")}

    ## Screener tiers

    | Tier | Applies | In register |
    |---|---|---|
    #{Enum.join(tier_rows, "\n")}

    ## Families (top 15)

    | Family | Both | Register only | Screener only |
    |---|---|---|---|
    #{Enum.join(family_rows, "\n")}
    """
  end

  defp sign(n) when n > 0, do: "+#{fmt(n)}"
  defp sign(n), do: fmt(n)
  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 3)
  defp fmt(n), do: to_string(n)
end
