defmodule SertantaiCompliance.Fitness.ProfileCheck do
  @moduledoc """
  Checks screening profiles against the expression-tree vocabulary, and
  describes that vocabulary for API and AI clients.

  A value the trees don't use is still accepted and stored (it records a true
  fact about the org, and legal may add the code later), but it can't match
  any law. `check/2` reports such values with suggestions so a client can
  correct them; strict clients can reject the profile instead.
  """

  alias SertantaiCompliance.Fitness.Vocabulary
  alias SertantaiCompliance.Sync.OrgScreeningProfile

  # Profile fields that are matched against expression trees, with the
  # dimension used when a value isn't in the vocabulary.
  @screened_fields [
    governed_actors: "personal",
    government_actors: "personal",
    locations: "material",
    materials: "material",
    processes: "material",
    sector: "material",
    regions: "territorial",
    conditions: "conditional"
  ]

  # Stored but not matched against expression trees.
  @unscreened_fields [:certifications, :contract_requirements, :activities]

  @type field ::
          :governed_actors
          | :government_actors
          | :locations
          | :materials
          | :processes
          | :sector
          | :regions
          | :conditions
          | :certifications
          | :contract_requirements
          | :activities

  @type unknown :: %{
          field: String.t(),
          value: String.t(),
          suggestions: [%{code: String.t(), dimension: String.t(), law_count: pos_integer()}]
        }

  @type result :: %{
          valid: boolean(),
          unknown: [unknown()],
          routed: %{String.t() => [String.t()]}
        }

  @doc "The profile fields matched against expression trees."
  @spec screened_fields() :: [field(), ...]
  def screened_fields, do: Keyword.keys(@screened_fields)

  @doc "Every profile field a client may set."
  @spec profile_fields() :: [field(), ...]
  def profile_fields, do: screened_fields() ++ @unscreened_fields

  @doc """
  Check a (possibly partial) profile map, with atom or string keys.

  Returns `valid: false` when any screened value isn't in the vocabulary,
  listing each with suggestions, plus the dimension routing the evaluator
  will use.
  """
  @spec check(map(), Vocabulary.t()) :: result()
  def check(profile, vocab \\ Vocabulary.current()) when is_map(profile) do
    {unknown, routed} =
      Enum.reduce(@screened_fields, {[], %{}}, fn {field, fallback}, {unknown, routed} ->
        values = get_list(profile, field)
        %{dimensions: dims, unknown: missing} = Vocabulary.route(values, vocab, fallback)

        unknown =
          unknown ++
            Enum.map(missing, fn value ->
              %{field: to_string(field), value: value, suggestions: suggestions(value, vocab)}
            end)

        {unknown, Map.merge(routed, dims, fn _dim, a, b -> Enum.uniq(a ++ b) end)}
      end)

    %{valid: unknown == [], unknown: unknown, routed: routed}
  end

  defp suggestions(value, vocab) do
    value
    |> Vocabulary.suggest(vocab)
    |> Enum.map(&Map.take(&1, [:code, :dimension, :law_count]))
  end

  @doc """
  Describe the vocabulary: how profiles are matched, each settable field,
  and every code per dimension with the number of laws that use it.
  """
  @spec describe(Vocabulary.t()) :: map()
  def describe(vocab \\ Vocabulary.current()) do
    %{
      about: """
      Laws are screened by evaluating their applicability expression trees
      against the profile. Trees match codes in four dimensions: personal (who
      you are), material (what you do or handle), territorial (where you
      operate, including place types such as premises, ship, aircraft) and
      conditional (facts such as at_work). Profile fields are groupings for
      people; each value is routed to the dimension the trees use it under.
      Actor labels may carry taxonomy prefixes ("Org: Employer"); they match
      the bare code ("employer"). Values not listed under dimensions are
      stored but cannot match any law.
      """,
      fields: Enum.map(profile_fields(), &describe_field/1),
      dimensions: describe_dimensions(vocab)
    }
  end

  defp describe_field(field) do
    attribute = Ash.Resource.Info.attribute(OrgScreeningProfile, field)

    %{
      name: to_string(field),
      description: attribute && attribute.description,
      screened: field in screened_fields(),
      default_dimension: Keyword.get(@screened_fields, field)
    }
  end

  defp describe_dimensions(vocab) do
    vocab
    |> Map.values()
    |> Enum.group_by(& &1.dimension)
    |> Map.new(fn {dimension, entries} ->
      {dimension,
       entries
       |> Enum.sort_by(&{-&1.law_count, &1.code})
       |> Enum.map(&Map.take(&1, [:code, :law_count]))}
    end)
  end

  defp get_list(map, key) do
    case Map.get(map, key, Map.get(map, to_string(key))) do
      values when is_list(values) -> Enum.filter(values, &is_binary/1)
      _ -> []
    end
  end
end
