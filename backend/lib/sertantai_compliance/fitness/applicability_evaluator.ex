defmodule SertantaiCompliance.Fitness.ApplicabilityEvaluator do
  @moduledoc """
  Evaluates compiled applicability expression trees against customer profiles.

  Fractalaw publishes compiled expression trees as JSON in `compiled_applicability`
  on each law record. This module walks the tree recursively to determine whether
  a law applies to a given customer profile.

  ## Node Types

  - `Match` — leaf node: does the customer's dimension contain any of the codes?
  - `And` — all children must match
  - `Or` — any child must match
  - `Not` — child must NOT match (DisappliesTo)
  - `Conditional` — evaluate `then` only if `condition` matches
  - `TimeWindow` — temporal gate: is today within [from, to]?

  ## Customer Profile

  A map of dimension → list of codes:

      %{
        "personal" => ["employer", "contractor"],
        "material" => ["construction_work"],
        "territorial" => ["england"],
        "conditional" => ["at_work"]
      }
  """

  @type profile :: %{String.t() => list(String.t())}
  @type tree :: map()
  @type result :: %{applies: boolean(), confidence: float()}

  @type reason :: %{
          dimension: String.t(),
          matched_codes: [String.t()],
          node_confidence: float()
        }

  @type detailed_result :: %{
          applies: boolean(),
          confidence: float(),
          reasons: [reason()],
          unmatched_dimensions: [String.t()]
        }

  @doc """
  Evaluate a compiled applicability tree against a customer profile.

  Returns `%{applies: boolean(), confidence: float()}`.

  If the tree is nil or invalid, returns `%{applies: false, confidence: 0.0}`.
  """
  @spec evaluate(tree() | nil, profile()) :: result()
  def evaluate(nil, _profile), do: %{applies: false, confidence: 0.0}

  def evaluate(tree, profile) when is_map(tree) and is_map(profile) do
    {applies, confidence} = eval_node(tree, profile)
    %{applies: applies, confidence: confidence}
  end

  def evaluate(tree, profile) when is_binary(tree) do
    case Jason.decode(tree) do
      {:ok, parsed} -> evaluate(parsed, profile)
      {:error, _} -> %{applies: false, confidence: 0.0}
    end
  end

  def evaluate(_, _), do: %{applies: false, confidence: 0.0}

  @doc """
  Evaluate a batch of laws against a profile.

  Takes a list of `%{name: String.t(), compiled_applicability: map() | nil}` and
  returns a list of `%{name: String.t(), applies: boolean(), confidence: float()}`.
  """
  @spec evaluate_batch(list(map()), profile()) :: list(map())
  def evaluate_batch(laws, profile) do
    Enum.map(laws, fn law ->
      result = evaluate(law.compiled_applicability, profile)
      Map.merge(%{name: law.name}, result)
    end)
  end

  # ── Evaluation with match reasons ──────────────────────────────

  @doc """
  Evaluate a compiled applicability tree against a customer profile,
  collecting match reasons at each Match node.

  Returns a detailed result with `reasons` (which dimensions/codes matched)
  and `unmatched_dimensions` (dimensions present in the tree but absent
  from the profile).

  If the tree is nil or invalid, returns a result with empty reasons.
  """
  @spec evaluate_with_reasons(tree() | nil, profile()) :: detailed_result()
  def evaluate_with_reasons(nil, _profile) do
    %{applies: false, confidence: 0.0, reasons: [], unmatched_dimensions: []}
  end

  def evaluate_with_reasons(tree, profile) when is_map(tree) and is_map(profile) do
    {applies, confidence, reasons} = eval_node_with_reasons(tree, profile)
    tree_dimensions = collect_dimensions(tree)
    profile_dimensions = MapSet.new(Map.keys(profile))

    unmatched =
      tree_dimensions
      |> MapSet.difference(profile_dimensions)
      |> MapSet.to_list()

    # Also include dimensions present in profile but with empty lists
    empty_profile_dims =
      tree_dimensions
      |> MapSet.intersection(profile_dimensions)
      |> Enum.filter(fn dim -> Map.get(profile, dim, []) == [] end)

    %{
      applies: applies,
      confidence: confidence,
      reasons: reasons,
      unmatched_dimensions: Enum.uniq(unmatched ++ empty_profile_dims)
    }
  end

  def evaluate_with_reasons(tree, profile) when is_binary(tree) do
    case Jason.decode(tree) do
      {:ok, parsed} -> evaluate_with_reasons(parsed, profile)
      {:error, _} -> %{applies: false, confidence: 0.0, reasons: [], unmatched_dimensions: []}
    end
  end

  def evaluate_with_reasons(_, _) do
    %{applies: false, confidence: 0.0, reasons: [], unmatched_dimensions: []}
  end

  @doc """
  Evaluate a batch of laws against a profile, collecting match reasons.

  Takes a list of maps with `:name` and `:compiled_applicability` keys.
  Returns a list of maps with the evaluation result merged in.
  """
  @spec evaluate_batch_with_reasons(list(map()), profile()) :: list(map())
  def evaluate_batch_with_reasons(laws, profile) do
    Enum.map(laws, fn law ->
      result = evaluate_with_reasons(law.compiled_applicability, profile)
      Map.merge(%{name: law.name}, result)
    end)
  end

  # ── Profile conversion ────────────────────────────────────────

  @doc """
  Convert an `OrgScreeningProfile` (or its map representation) into the
  evaluator's dimension-keyed profile format.

  Maps profile fields to expression tree dimensions:
  - `governed_actors` + `government_actors` → `"personal"`
  - `locations`, `materials`, `processes`, `sector` → `"material"`
  - `regions` → `"territorial"`

  The `"conditional"` and `"temporal"` dimensions must be provided separately
  if needed (e.g. from questionnaire answers).
  """
  @spec profile_from_screening(map()) :: profile()
  def profile_from_screening(screening_profile) when is_map(screening_profile) do
    profile = %{}

    # Personal dimension: actor labels (normalised to lowercase)
    personal =
      (get_list(screening_profile, :governed_actors) ++
         get_list(screening_profile, :government_actors))
      |> Enum.map(&normalise_code/1)
      |> Enum.uniq()

    profile = if personal != [], do: Map.put(profile, "personal", personal), else: profile

    # Material dimension: locations + materials + processes + sector
    material =
      (get_list(screening_profile, :locations) ++
         get_list(screening_profile, :materials) ++
         get_list(screening_profile, :processes) ++
         get_list(screening_profile, :sector))
      |> Enum.map(&normalise_code/1)
      |> Enum.uniq()

    profile = if material != [], do: Map.put(profile, "material", material), else: profile

    # Territorial dimension: regions (lowercased)
    territorial =
      get_list(screening_profile, :regions)
      |> Enum.map(&normalise_code/1)
      |> Enum.uniq()

    profile =
      if territorial != [], do: Map.put(profile, "territorial", territorial), else: profile

    # Conditional dimension: pass through if present
    conditional = get_list(screening_profile, :conditional)

    profile =
      if conditional != [], do: Map.put(profile, "conditional", conditional), else: profile

    profile
  end

  defp get_list(map, key) when is_atom(key) do
    case Map.get(map, key) do
      nil ->
        case Map.get(map, to_string(key)) do
          nil -> []
          val when is_list(val) -> val
          _ -> []
        end

      val when is_list(val) ->
        val

      _ ->
        []
    end
  end

  defp normalise_code(code) when is_binary(code) do
    code |> String.downcase() |> String.replace(~r/\s+/, "_")
  end

  # ── Hierarchy expansion ───────────────────────────────────────────

  # Territorial: each region implies its parent jurisdictions
  @territorial_ancestors %{
    "england" => ["england_and_wales", "great_britain", "united_kingdom"],
    "wales" => ["england_and_wales", "great_britain", "united_kingdom"],
    "scotland" => ["great_britain", "united_kingdom"],
    "northern_ireland" => ["united_kingdom"],
    "england_and_wales" => ["great_britain", "united_kingdom"],
    "great_britain" => ["united_kingdom"]
  }

  defp expand_codes("territorial", codes) do
    Enum.flat_map(codes, fn code ->
      [code | Map.get(@territorial_ancestors, code, [])]
    end)
    |> Enum.uniq()
  end

  defp expand_codes(_dimension, codes), do: codes

  # ── Match confidence heuristic ──────────────────────────────────

  # Computes confidence for a matching Match node based on how specifically
  # the profile's codes matched the node's codes.
  #
  # Two factors:
  #   1. Specificity: direct match (1.0) vs ancestor/hierarchy match (0.5)
  #   2. Overlap: what fraction of the node's codes did the profile match?
  #
  # Returns a float in (0, 1.0].
  defp compute_match_confidence(dim, node_codes, profile) do
    raw_profile_codes = Map.get(profile, dim, [])
    expanded_profile_codes = expand_codes(dim, raw_profile_codes)

    # Which node codes matched, and how?
    {direct_count, ancestor_count} =
      Enum.reduce(node_codes, {0, 0}, fn code, {direct, ancestor} ->
        cond do
          code in raw_profile_codes -> {direct + 1, ancestor}
          code in expanded_profile_codes -> {direct, ancestor + 1}
          true -> {direct, ancestor}
        end
      end)

    total_matched = direct_count + ancestor_count

    # Specificity factor: [0.75, 1.0]
    specificity =
      if total_matched > 0 do
        raw = (direct_count + 0.5 * ancestor_count) / total_matched
        0.5 + 0.5 * raw
      else
        1.0
      end

    # Overlap factor: [0.4, 1.0]
    total_node_codes = length(node_codes)

    overlap =
      if total_node_codes > 0 do
        0.4 + 0.6 * (total_matched / total_node_codes)
      else
        1.0
      end

    Float.round(specificity * overlap, 4)
  end

  # ── Node evaluation ──────────────────────────────────────────────

  defp eval_node(%{"op" => "Match", "dimension" => dim, "codes" => codes} = node, profile) do
    customer_codes = expand_codes(dim, Map.get(profile, dim, []))
    applies = Enum.any?(codes, &(&1 in customer_codes))

    confidence =
      case Map.get(node, "confidence") do
        c when is_number(c) and c > 0 -> c
        _ -> if applies, do: compute_match_confidence(dim, codes, profile), else: 1.0
      end

    {applies, confidence}
  end

  defp eval_node(%{"op" => "And", "children" => children}, profile) do
    results = Enum.map(children, &eval_node(&1, profile))
    applies = Enum.all?(results, fn {a, _c} -> a end)
    # And confidence: minimum of children (weakest link)
    confidence = results |> Enum.map(fn {_a, c} -> c end) |> Enum.min(fn -> 1.0 end)
    {applies, confidence}
  end

  defp eval_node(%{"op" => "Or", "children" => children}, profile) do
    results = Enum.map(children, &eval_node(&1, profile))
    applies = Enum.any?(results, fn {a, _c} -> a end)
    # Or confidence: maximum of matching children
    confidence =
      results
      |> Enum.filter(fn {a, _c} -> a end)
      |> Enum.map(fn {_a, c} -> c end)
      |> Enum.max(fn -> Enum.map(results, fn {_a, c} -> c end) |> Enum.max(fn -> 1.0 end) end)

    {applies, confidence}
  end

  defp eval_node(%{"op" => "Not", "child" => child}, profile) do
    {child_applies, confidence} = eval_node(child, profile)
    {not child_applies, confidence}
  end

  defp eval_node(%{"op" => "Conditional", "condition" => condition, "then" => then_node}, profile) do
    {cond_applies, _cond_conf} = eval_node(condition, profile)

    if cond_applies do
      eval_node(then_node, profile)
    else
      {false, 1.0}
    end
  end

  defp eval_node(%{"op" => "TimeWindow", "from" => from, "to" => to} = node, profile) do
    today = Date.utc_today()
    after_from = is_nil(from) or Date.compare(today, Date.from_iso8601!(from)) != :lt
    before_to = is_nil(to) or Date.compare(today, Date.from_iso8601!(to)) != :gt
    in_window = after_from and before_to

    # TimeWindow may wrap an inner node, or be a standalone temporal gate
    case Map.get(node, "inner") do
      nil -> {in_window, 1.0}
      inner -> if in_window, do: eval_node(inner, profile), else: {false, 1.0}
    end
  end

  # Catch-all for unknown node types
  defp eval_node(_node, _profile), do: {false, 0.0}

  # ── Node evaluation with reasons ────────────────────────────────

  # Returns {applies, confidence, reasons} where reasons is a list of
  # %{dimension, matched_codes, node_confidence} from Match nodes.

  defp eval_node_with_reasons(
         %{"op" => "Match", "dimension" => dim, "codes" => codes} = node,
         profile
       ) do
    customer_codes = expand_codes(dim, Map.get(profile, dim, []))
    matched = Enum.filter(codes, &(&1 in customer_codes))
    applies = matched != []

    confidence =
      case Map.get(node, "confidence") do
        c when is_number(c) and c > 0 -> c
        _ -> if applies, do: compute_match_confidence(dim, codes, profile), else: 1.0
      end

    reasons =
      if applies do
        [%{dimension: dim, matched_codes: matched, node_confidence: confidence}]
      else
        []
      end

    {applies, confidence, reasons}
  end

  defp eval_node_with_reasons(%{"op" => "And", "children" => children}, profile) do
    results = Enum.map(children, &eval_node_with_reasons(&1, profile))
    applies = Enum.all?(results, fn {a, _c, _r} -> a end)
    confidence = results |> Enum.map(fn {_a, c, _r} -> c end) |> Enum.min(fn -> 1.0 end)
    reasons = results |> Enum.flat_map(fn {_a, _c, r} -> r end)
    {applies, confidence, reasons}
  end

  defp eval_node_with_reasons(%{"op" => "Or", "children" => children}, profile) do
    results = Enum.map(children, &eval_node_with_reasons(&1, profile))
    applies = Enum.any?(results, fn {a, _c, _r} -> a end)

    confidence =
      results
      |> Enum.filter(fn {a, _c, _r} -> a end)
      |> Enum.map(fn {_a, c, _r} -> c end)
      |> Enum.max(fn ->
        results |> Enum.map(fn {_a, c, _r} -> c end) |> Enum.max(fn -> 1.0 end)
      end)

    # Collect reasons from matching branches only
    reasons =
      results
      |> Enum.filter(fn {a, _c, _r} -> a end)
      |> Enum.flat_map(fn {_a, _c, r} -> r end)

    {applies, confidence, reasons}
  end

  defp eval_node_with_reasons(%{"op" => "Not", "child" => child}, profile) do
    {child_applies, confidence, reasons} = eval_node_with_reasons(child, profile)
    {not child_applies, confidence, reasons}
  end

  defp eval_node_with_reasons(
         %{"op" => "Conditional", "condition" => condition, "then" => then_node},
         profile
       ) do
    {cond_applies, _cond_conf, cond_reasons} = eval_node_with_reasons(condition, profile)

    if cond_applies do
      {then_applies, then_conf, then_reasons} = eval_node_with_reasons(then_node, profile)
      {then_applies, then_conf, cond_reasons ++ then_reasons}
    else
      {false, 1.0, []}
    end
  end

  defp eval_node_with_reasons(
         %{"op" => "TimeWindow", "from" => from, "to" => to} = node,
         profile
       ) do
    today = Date.utc_today()
    after_from = is_nil(from) or Date.compare(today, Date.from_iso8601!(from)) != :lt
    before_to = is_nil(to) or Date.compare(today, Date.from_iso8601!(to)) != :gt
    in_window = after_from and before_to

    case Map.get(node, "inner") do
      nil ->
        {in_window, 1.0, []}

      inner ->
        if in_window do
          eval_node_with_reasons(inner, profile)
        else
          {false, 1.0, []}
        end
    end
  end

  defp eval_node_with_reasons(_node, _profile), do: {false, 0.0, []}

  # ── Dimension collection ────────────────────────────────────────

  # Walks the tree to find all unique dimensions referenced in Match nodes.
  defp collect_dimensions(%{"op" => "Match", "dimension" => dim}), do: MapSet.new([dim])

  defp collect_dimensions(%{"op" => op, "children" => children})
       when op in ["And", "Or"] do
    Enum.reduce(children, MapSet.new(), fn child, acc ->
      MapSet.union(acc, collect_dimensions(child))
    end)
  end

  defp collect_dimensions(%{"op" => "Not", "child" => child}), do: collect_dimensions(child)

  defp collect_dimensions(%{"op" => "Conditional", "condition" => cond_node, "then" => then_node}) do
    MapSet.union(collect_dimensions(cond_node), collect_dimensions(then_node))
  end

  defp collect_dimensions(%{"op" => "TimeWindow"} = node) do
    case Map.get(node, "inner") do
      nil -> MapSet.new()
      inner -> collect_dimensions(inner)
    end
  end

  defp collect_dimensions(_), do: MapSet.new()
end
