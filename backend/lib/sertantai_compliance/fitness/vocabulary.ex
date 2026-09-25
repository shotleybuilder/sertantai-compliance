defmodule SertantaiCompliance.Fitness.Vocabulary do
  @moduledoc """
  The screening vocabulary, derived from the codes that compiled applicability
  expression trees actually use.

  Every `Match` node in `legal_register.compiled_applicability` carries a
  `dimension` (personal / material / territorial / conditional) and a list of
  `codes`. This module indexes those codes so that profile values can be:

    * **normalised** — `"Org: Employer"` → `"employer"` (actor taxonomy prefixes
      are stripped; trees use bare codes)
    * **routed** — each code goes to the dimension the trees use it under
      (e.g. `premises` is territorial even though the profile stores it under
      `locations`)
    * **validated** — unknown values get closest-match suggestions

  The vocabulary is built from the corpus and cached; it changes only when
  legal publishes new trees.
  """

  alias SertantaiCompliance.Repo

  @type entry :: %{
          code: String.t(),
          dimension: String.t(),
          uses: pos_integer(),
          law_count: pos_integer()
        }
  @type t :: %{String.t() => entry()}

  @cache_key {__MODULE__, :vocabulary}
  @ttl_ms :timer.minutes(10)

  # Same corpus the screener evaluates: in-force UK Making laws with trees.
  @vocabulary_sql """
  WITH RECURSIVE nodes(law, n) AS (
    SELECT name, compiled_applicability
    FROM legal_register
    WHERE compiled_applicability IS NOT NULL
      AND is_making = true
      AND country = 'uk'
      AND (live IS NULL OR (live NOT LIKE '%Revoked%' AND live NOT LIKE '%Repealed%' AND live NOT LIKE '%Abolished%'))
    UNION ALL
    SELECT law, jsonb_array_elements(n->'children') FROM nodes WHERE n ? 'children'
  ),
  codes AS (
    SELECT law, n->>'dimension' AS dimension, jsonb_array_elements_text(n->'codes') AS code
    FROM nodes
    WHERE n->>'op' = 'Match'
  )
  SELECT code, dimension, COUNT(*) AS uses, COUNT(DISTINCT law) AS law_count
  FROM codes
  GROUP BY code, dimension
  """

  @doc "The cached vocabulary, rebuilt from the corpus when older than #{div(@ttl_ms, 60_000)} minutes."
  @spec current() :: t()
  def current do
    now = System.monotonic_time(:millisecond)

    ttl = Application.get_env(:sertantai_compliance, :vocabulary_cache_ttl_ms, @ttl_ms)

    case :persistent_term.get(@cache_key, nil) do
      {built_at, vocab} when now - built_at < ttl -> vocab
      _ -> refresh()
    end
  end

  @doc "Rebuild the vocabulary from the corpus and cache it."
  @spec refresh() :: t()
  def refresh do
    vocab = build()
    :persistent_term.put(@cache_key, {System.monotonic_time(:millisecond), vocab})
    vocab
  end

  @doc """
  Build the vocabulary from the corpus.

  If a code were used under more than one dimension, the most-used one wins
  (none are today; see sertantai-legal#161).
  """
  @spec build() :: t()
  def build do
    %{rows: rows} = Repo.query!(@vocabulary_sql)
    from_rows(rows)
  end

  @doc false
  # Exposed for tests: rows of [code, dimension, uses, law_count].
  @spec from_rows([[term()]]) :: t()
  def from_rows(rows) do
    rows
    |> Enum.map(fn [code, dimension, uses, law_count] ->
      %{code: code, dimension: dimension, uses: uses, law_count: law_count}
    end)
    |> Enum.group_by(& &1.code)
    |> Map.new(fn {code, entries} -> {code, Enum.max_by(entries, & &1.uses)} end)
  end

  @doc """
  Normalise a profile value to the tree code convention.

  Strips actor taxonomy prefixes (`"SC: C: Contractor"` → `"contractor"`),
  lowercases, and joins words with underscores.

      iex> SertantaiCompliance.Fitness.Vocabulary.normalise("Org: Employer")
      "employer"
      iex> SertantaiCompliance.Fitness.Vocabulary.normalise("Diving Operations")
      "diving_operations"
  """
  @spec normalise(String.t()) :: String.t()
  def normalise(value) when is_binary(value) do
    value
    |> String.split(":")
    |> List.last()
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, "_")
  end

  @doc "Look up a profile value. Returns the vocabulary entry or `:unknown`."
  @spec lookup(String.t(), t()) :: {:ok, entry()} | :unknown
  def lookup(value, vocab) do
    case Map.fetch(vocab, normalise(value)) do
      {:ok, entry} -> {:ok, entry}
      :error -> :unknown
    end
  end

  @doc """
  Suggest up to `limit` vocabulary codes close to `value`, most relevant first.

  Combines string similarity with containment ("radioactive" suggests
  `radioactive`, "radioactive_materials" suggests `radioactive` too), and
  prefers codes used by more laws when scores tie.
  """
  @spec suggest(String.t(), t(), pos_integer()) :: [entry()]
  def suggest(value, vocab, limit \\ 3) do
    target = normalise(value)
    words = String.split(target, "_", trim: true)

    vocab
    |> Map.values()
    |> Enum.map(fn entry -> {score(target, words, entry.code), entry} end)
    |> Enum.filter(fn {score, _} -> score >= 0.8 end)
    |> Enum.sort_by(fn {score, entry} -> {-score, -entry.law_count} end)
    |> Enum.take(limit)
    |> Enum.map(fn {_, entry} -> entry end)
  end

  # Spelling similarity only counts when it's a likely typo (employr → employer
  # 0.96, premisses → premises 0.92); defence → evidence (0.81) is a coincidence.
  @typo_threshold 0.9

  defp score(target, words, code) do
    jaro = String.jaro_distance(target, code)
    jaro = if jaro >= @typo_threshold, do: jaro, else: 0.0
    code_words = String.split(code, "_", trim: true)
    shared = Enum.count(words, &(&1 in code_words))

    containment =
      cond do
        shared > 0 and String.length(code) >= 4 -> 0.8 + 0.1 * shared / max(length(words), 1)
        true -> 0.0
      end

    max(jaro, containment)
  end

  @doc """
  Route a list of profile values to evaluator dimensions.

  Known codes go to the dimension the trees use them under. Unknown codes go
  to `fallback_dimension` (they can't match any tree, but are kept so the
  profile still round-trips) and are reported in `:unknown`.
  """
  @spec route([String.t()], t(), String.t()) :: %{
          dimensions: %{String.t() => [String.t()]},
          unknown: [String.t()]
        }
  def route(values, vocab, fallback_dimension) do
    Enum.reduce(values, %{dimensions: %{}, unknown: []}, fn value, acc ->
      code = normalise(value)

      {dimension, acc} =
        case Map.fetch(vocab, code) do
          {:ok, entry} -> {entry.dimension, acc}
          :error -> {fallback_dimension, %{acc | unknown: acc.unknown ++ [value]}}
        end

      update_in(acc, [:dimensions, Access.key(dimension, [])], &Enum.uniq(&1 ++ [code]))
    end)
  end
end
