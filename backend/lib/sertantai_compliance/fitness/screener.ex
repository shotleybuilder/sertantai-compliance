defmodule SertantaiCompliance.Fitness.Screener do
  @moduledoc """
  One screening run: evaluate an org profile against the screening corpus.

  Shared by the screening API (`POST /api/screening/evaluate`) and the
  benchmark (`mix screener.benchmark`), so the benchmark measures exactly what
  users see.

  The corpus is in-force UK Making laws. Laws without a compiled
  applicability tree are included (they can never apply) so callers can
  report coverage.
  """

  alias SertantaiCompliance.Fitness.ApplicabilityEvaluator
  alias SertantaiCompliance.Repo

  @type law :: %{
          name: String.t(),
          title_en: String.t() | nil,
          family: String.t() | nil,
          compiled_applicability: map() | nil,
          significance_rating: String.t() | nil,
          significance_score: float() | nil,
          geo_extent: String.t() | nil,
          duty_holder: map() | nil,
          power_holder: map() | nil,
          rights_holder: map() | nil,
          responsibility_holder: map() | nil,
          fitness_entities: [String.t()] | nil,
          is_making: boolean()
        }

  @type screened :: %{
          law: law(),
          applies: boolean(),
          confidence: float(),
          reasons: [ApplicabilityEvaluator.reason()],
          caveats: [ApplicabilityEvaluator.caveat()],
          unmatched_dimensions: [String.t()]
        }

  @corpus_sql """
  SELECT name, title_en, family, compiled_applicability,
         significance_rating, significance_score, geo_extent,
         duty_holder, power_holder, rights_holder, responsibility_holder,
         fitness_entities, is_making
  FROM legal_register
  WHERE is_making = true
    AND country = 'uk'
    AND (live IS NULL OR (live NOT LIKE '%Revoked%' AND live NOT LIKE '%Repealed%' AND live NOT LIKE '%Abolished%'))
  ORDER BY name
  """

  @doc "Load the screening corpus: in-force UK Making laws, ordered by name."
  @spec corpus() :: [law()]
  def corpus do
    %{rows: rows} = Repo.query!(@corpus_sql, [])

    Enum.map(rows, fn [
                        name,
                        title_en,
                        family,
                        compiled_app,
                        sig_rating,
                        sig_score,
                        geo_extent,
                        duty_holder,
                        power_holder,
                        rights_holder,
                        resp_holder,
                        fitness_entities,
                        is_making
                      ] ->
      %{
        name: name,
        title_en: title_en,
        family: family,
        compiled_applicability: decode_jsonb(compiled_app),
        significance_rating: sig_rating,
        significance_score: sig_score,
        geo_extent: geo_extent,
        duty_holder: decode_jsonb(duty_holder),
        power_holder: decode_jsonb(power_holder),
        rights_holder: decode_jsonb(rights_holder),
        responsibility_holder: decode_jsonb(resp_holder),
        fitness_entities: fitness_entities,
        is_making: is_making
      }
    end)
  end

  @doc """
  Screen `laws` (default: the whole corpus) against an evaluator `profile`
  (see `ApplicabilityEvaluator.profile_from_screening/2`). Returns one result
  per law, in corpus order.
  """
  @spec screen(ApplicabilityEvaluator.profile(), [law()] | nil) :: [screened()]
  def screen(profile, laws \\ nil) do
    laws = laws || corpus()
    by_name = Map.new(laws, &{&1.name, &1})

    laws
    |> ApplicabilityEvaluator.evaluate_batch_with_reasons(profile)
    |> Enum.map(fn result ->
      %{
        law: Map.fetch!(by_name, result.name),
        applies: result.applies,
        confidence: result.confidence,
        reasons: result.reasons,
        caveats: result.caveats,
        unmatched_dimensions: result.unmatched_dimensions
      }
    end)
  end

  # Postgrex may return JSONB as a raw string when no custom JSON decoder is
  # configured. Decode to a map/list if needed.
  defp decode_jsonb(val) when is_binary(val) do
    case Jason.decode(val) do
      {:ok, parsed} -> parsed
      {:error, _} -> val
    end
  end

  defp decode_jsonb(val), do: val
end
