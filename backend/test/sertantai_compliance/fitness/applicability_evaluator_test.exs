defmodule SertantaiCompliance.Fitness.ApplicabilityEvaluatorTest do
  use ExUnit.Case, async: true

  alias SertantaiCompliance.Fitness.ApplicabilityEvaluator

  # ── evaluate_with_reasons/2 ─────────────────────────────────────

  describe "evaluate_with_reasons/2" do
    test "returns empty result for nil tree" do
      result = ApplicabilityEvaluator.evaluate_with_reasons(nil, %{"personal" => ["employer"]})

      assert result == %{
               applies: false,
               confidence: 0.0,
               reasons: [],
               unmatched_dimensions: []
             }
    end

    test "Match node — matching codes" do
      tree = %{"op" => "Match", "dimension" => "personal", "codes" => ["employer", "contractor"]}
      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
      # Heuristic: 1 of 2 codes matched directly → overlap = 0.4 + 0.6*(1/2) = 0.7
      assert result.confidence == 0.7
      assert length(result.reasons) == 1

      [reason] = result.reasons
      assert reason.dimension == "personal"
      assert reason.matched_codes == ["employer"]
      assert reason.node_confidence == 0.7
      assert result.unmatched_dimensions == []
    end

    test "Match node — no matching codes" do
      tree = %{"op" => "Match", "dimension" => "personal", "codes" => ["manufacturer"]}
      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == false
      assert result.reasons == []
    end

    test "Match node — with custom confidence" do
      tree = %{
        "op" => "Match",
        "dimension" => "material",
        "codes" => ["asbestos"],
        "confidence" => 0.85
      }

      profile = %{"material" => ["asbestos"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
      assert result.confidence == 0.85
      [reason] = result.reasons
      assert reason.node_confidence == 0.85
    end

    test "Match node — unmatched dimension (not in profile)" do
      tree = %{"op" => "Match", "dimension" => "conditional", "codes" => ["at_work"]}
      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == false
      assert "conditional" in result.unmatched_dimensions
    end

    test "Match node — dimension in profile but empty list" do
      tree = %{"op" => "Match", "dimension" => "material", "codes" => ["asbestos"]}
      profile = %{"material" => []}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == false
      assert "material" in result.unmatched_dimensions
    end

    test "And node — all children match" do
      tree = %{
        "op" => "And",
        "children" => [
          %{"op" => "Match", "dimension" => "personal", "codes" => ["employer"]},
          %{
            "op" => "Match",
            "dimension" => "territorial",
            "codes" => ["england"],
            "confidence" => 0.9
          }
        ]
      }

      profile = %{"personal" => ["employer"], "territorial" => ["england"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
      # And confidence = min of children
      assert result.confidence == 0.9
      assert length(result.reasons) == 2

      dims = Enum.map(result.reasons, & &1.dimension)
      assert "personal" in dims
      assert "territorial" in dims
    end

    test "And node — one child fails" do
      tree = %{
        "op" => "And",
        "children" => [
          %{"op" => "Match", "dimension" => "personal", "codes" => ["employer"]},
          %{"op" => "Match", "dimension" => "material", "codes" => ["nuclear"]}
        ]
      }

      profile = %{"personal" => ["employer"], "material" => ["construction"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == false
      # Still collects reasons from matching nodes
      assert length(result.reasons) == 1
      assert hd(result.reasons).dimension == "personal"
    end

    test "Or node — one child matches" do
      tree = %{
        "op" => "Or",
        "children" => [
          %{"op" => "Match", "dimension" => "personal", "codes" => ["manufacturer"]},
          %{
            "op" => "Match",
            "dimension" => "personal",
            "codes" => ["employer"],
            "confidence" => 0.95
          }
        ]
      }

      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
      assert result.confidence == 0.95
      # Only matching branches contribute reasons
      assert length(result.reasons) == 1
      assert hd(result.reasons).matched_codes == ["employer"]
    end

    test "Or node — no children match" do
      tree = %{
        "op" => "Or",
        "children" => [
          %{"op" => "Match", "dimension" => "personal", "codes" => ["manufacturer"]},
          %{"op" => "Match", "dimension" => "personal", "codes" => ["importer"]}
        ]
      }

      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == false
      assert result.reasons == []
    end

    test "Not node — negates child result" do
      tree = %{
        "op" => "Not",
        "child" => %{"op" => "Match", "dimension" => "personal", "codes" => ["crown"]}
      }

      # Crown not in profile → Not(false) = true
      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
    end

    test "Not node — negates matching child" do
      tree = %{
        "op" => "Not",
        "child" => %{"op" => "Match", "dimension" => "personal", "codes" => ["employer"]}
      }

      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == false
      # Reasons still collected from the inner Match
      assert length(result.reasons) == 1
    end

    test "Conditional node — condition met, evaluates then" do
      tree = %{
        "op" => "Conditional",
        "condition" => %{
          "op" => "Match",
          "dimension" => "conditional",
          "codes" => ["employees_gte_5"]
        },
        "then" => %{
          "op" => "Match",
          "dimension" => "personal",
          "codes" => ["employer"],
          "confidence" => 0.92
        }
      }

      profile = %{"conditional" => ["employees_gte_5"], "personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
      assert result.confidence == 0.92
      assert length(result.reasons) == 2

      dims = Enum.map(result.reasons, & &1.dimension)
      assert "conditional" in dims
      assert "personal" in dims
    end

    test "Conditional node — condition not met, skips then" do
      tree = %{
        "op" => "Conditional",
        "condition" => %{
          "op" => "Match",
          "dimension" => "conditional",
          "codes" => ["employees_gte_5"]
        },
        "then" => %{"op" => "Match", "dimension" => "personal", "codes" => ["employer"]}
      }

      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == false
      assert result.reasons == []
    end

    test "TimeWindow node — in window" do
      yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()
      tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      tree = %{
        "op" => "TimeWindow",
        "from" => yesterday,
        "to" => tomorrow,
        "inner" => %{
          "op" => "Match",
          "dimension" => "personal",
          "codes" => ["employer"]
        }
      }

      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
      assert length(result.reasons) == 1
    end

    test "TimeWindow node — outside window" do
      past = Date.utc_today() |> Date.add(-30) |> Date.to_iso8601()
      also_past = Date.utc_today() |> Date.add(-10) |> Date.to_iso8601()

      tree = %{
        "op" => "TimeWindow",
        "from" => past,
        "to" => also_past,
        "inner" => %{
          "op" => "Match",
          "dimension" => "personal",
          "codes" => ["employer"]
        }
      }

      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == false
      assert result.reasons == []
    end

    test "territorial hierarchy expansion reflected in reasons" do
      tree = %{
        "op" => "Match",
        "dimension" => "territorial",
        "codes" => ["great_britain"]
      }

      # Selecting "england" should expand to include "great_britain"
      profile = %{"territorial" => ["england"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
      [reason] = result.reasons
      assert reason.dimension == "territorial"
      assert "great_britain" in reason.matched_codes
    end

    test "complex nested tree — And(Or, Match)" do
      tree = %{
        "op" => "And",
        "children" => [
          %{
            "op" => "Or",
            "children" => [
              %{
                "op" => "Match",
                "dimension" => "personal",
                "codes" => ["employer"],
                "confidence" => 0.9
              },
              %{
                "op" => "Match",
                "dimension" => "personal",
                "codes" => ["contractor"],
                "confidence" => 0.8
              }
            ]
          },
          %{
            "op" => "Match",
            "dimension" => "territorial",
            "codes" => ["england"],
            "confidence" => 1.0
          }
        ]
      }

      profile = %{"personal" => ["employer"], "territorial" => ["england"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
      # And confidence = min(Or confidence, Match confidence) = min(0.9, 1.0) = 0.9
      assert result.confidence == 0.9
      assert length(result.reasons) == 2
    end

    test "handles JSON string tree" do
      tree =
        Jason.encode!(%{
          "op" => "Match",
          "dimension" => "personal",
          "codes" => ["employer"]
        })

      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == true
      assert length(result.reasons) == 1
    end

    test "unknown node type returns false with empty reasons" do
      tree = %{"op" => "Unknown", "data" => "something"}
      profile = %{"personal" => ["employer"]}

      result = ApplicabilityEvaluator.evaluate_with_reasons(tree, profile)

      assert result.applies == false
      assert result.confidence == 0.0
      assert result.reasons == []
    end
  end

  # ── confidence heuristic ──────────────────────────────────────

  describe "confidence heuristic" do
    test "direct match on single code gives 1.0" do
      tree = %{"op" => "Match", "dimension" => "personal", "codes" => ["employer"]}
      profile = %{"personal" => ["employer"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      assert result.confidence == 1.0
    end

    test "direct match on 1 of 2 codes gives 0.7" do
      tree = %{"op" => "Match", "dimension" => "personal", "codes" => ["employer", "contractor"]}
      profile = %{"personal" => ["employer"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      assert result.confidence == 0.7
    end

    test "direct match on all of 2 codes gives 1.0" do
      tree = %{"op" => "Match", "dimension" => "personal", "codes" => ["employer", "contractor"]}
      profile = %{"personal" => ["employer", "contractor"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      assert result.confidence == 1.0
    end

    test "direct match on 1 of 5 codes" do
      tree = %{
        "op" => "Match",
        "dimension" => "personal",
        "codes" => ["employer", "contractor", "manufacturer", "supplier", "importer"]
      }

      profile = %{"personal" => ["employer"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      # overlap = 0.4 + 0.6*(1/5) = 0.52, specificity = 1.0
      assert_in_delta result.confidence, 0.52, 0.01
    end

    test "territorial ancestor match on single code gives 0.75" do
      tree = %{"op" => "Match", "dimension" => "territorial", "codes" => ["great_britain"]}
      profile = %{"territorial" => ["england"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      assert result.confidence == 0.75
    end

    test "territorial direct match gives 1.0" do
      tree = %{"op" => "Match", "dimension" => "territorial", "codes" => ["england"]}
      profile = %{"territorial" => ["england"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      assert result.confidence == 1.0
    end

    test "mixed direct and ancestor territorial match" do
      tree = %{
        "op" => "Match",
        "dimension" => "territorial",
        "codes" => ["england", "great_britain"]
      }

      profile = %{"territorial" => ["england"]}
      # england is direct, great_britain is ancestor. Both matched.
      # specificity = 0.5 + 0.5 * (1 + 0.5*1)/2 = 0.875
      # overlap = 0.4 + 0.6 * 1.0 = 1.0
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      assert_in_delta result.confidence, 0.875, 0.01
    end

    test "upstream confidence takes precedence" do
      tree = %{
        "op" => "Match",
        "dimension" => "personal",
        "codes" => ["employer", "contractor", "manufacturer"],
        "confidence" => 0.85
      }

      profile = %{"personal" => ["employer"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      assert result.confidence == 0.85
    end

    test "And propagation with heuristic children" do
      tree = %{
        "op" => "And",
        "children" => [
          %{"op" => "Match", "dimension" => "personal", "codes" => ["employer", "contractor"]},
          %{"op" => "Match", "dimension" => "territorial", "codes" => ["great_britain"]}
        ]
      }

      profile = %{"personal" => ["employer"], "territorial" => ["england"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      # personal: overlap = 0.7, specificity = 1.0 → 0.7
      # territorial: overlap = 1.0, specificity = 0.75 → 0.75
      # And = min(0.7, 0.75) = 0.7
      assert_in_delta result.confidence, 0.7, 0.01
    end

    test "Or propagation picks strongest heuristic child" do
      tree = %{
        "op" => "Or",
        "children" => [
          %{
            "op" => "Match",
            "dimension" => "personal",
            "codes" => ["employer", "contractor", "manufacturer", "supplier"]
          },
          %{"op" => "Match", "dimension" => "personal", "codes" => ["employer"]}
        ]
      }

      profile = %{"personal" => ["employer"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      # child1: overlap = 0.55, specificity = 1.0 → 0.55
      # child2: overlap = 1.0, specificity = 1.0 → 1.0
      # Or = max(0.55, 1.0) = 1.0
      assert result.confidence == 1.0
    end

    test "non-matching node returns applies false" do
      tree = %{"op" => "Match", "dimension" => "personal", "codes" => ["manufacturer"]}
      profile = %{"personal" => ["employer"]}
      result = ApplicabilityEvaluator.evaluate(tree, profile)
      assert result.applies == false
    end

    test "heuristic is deterministic" do
      tree = %{
        "op" => "Match",
        "dimension" => "personal",
        "codes" => ["employer", "contractor", "manufacturer"]
      }

      profile = %{"personal" => ["employer"]}
      r1 = ApplicabilityEvaluator.evaluate(tree, profile)
      r2 = ApplicabilityEvaluator.evaluate(tree, profile)
      assert r1.confidence == r2.confidence
    end
  end

  # ── evaluate_batch_with_reasons/2 ──────────────────────────────

  describe "evaluate_batch_with_reasons/2" do
    test "evaluates multiple laws" do
      laws = [
        %{
          name: "LAW_A",
          compiled_applicability: %{
            "op" => "Match",
            "dimension" => "personal",
            "codes" => ["employer"]
          }
        },
        %{
          name: "LAW_B",
          compiled_applicability: %{
            "op" => "Match",
            "dimension" => "personal",
            "codes" => ["manufacturer"]
          }
        },
        %{
          name: "LAW_C",
          compiled_applicability: nil
        }
      ]

      profile = %{"personal" => ["employer"]}

      results = ApplicabilityEvaluator.evaluate_batch_with_reasons(laws, profile)

      assert length(results) == 3

      law_a = Enum.find(results, fn r -> r.name == "LAW_A" end)
      assert law_a.applies == true
      assert length(law_a.reasons) == 1

      law_b = Enum.find(results, fn r -> r.name == "LAW_B" end)
      assert law_b.applies == false
      assert law_b.reasons == []

      law_c = Enum.find(results, fn r -> r.name == "LAW_C" end)
      assert law_c.applies == false
      assert law_c.reasons == []
    end
  end

  # ── profile_from_screening/2 ───────────────────────────────────

  alias SertantaiCompliance.Fitness.Vocabulary

  # Minimal tree vocabulary: [code, dimension, uses, law_count]
  @vocab Vocabulary.from_rows([
           ["employer", "personal", 161, 60],
           ["contractor", "personal", 11, 9],
           ["england", "territorial", 477, 167],
           ["scotland", "territorial", 491, 152],
           ["offshore", "territorial", 109, 40],
           ["premises", "territorial", 308, 100],
           ["asbestos", "material", 20, 8],
           ["construction_work", "material", 93, 30],
           ["maritime", "material", 10, 5],
           ["at_work", "conditional", 88, 73]
         ])

  describe "profile_from_screening/2" do
    test "strips actor taxonomy prefixes so labels match bare tree codes" do
      screening = %{governed_actors: ["Org: Employer"], government_actors: ["SC: C: Contractor"]}

      profile = ApplicabilityEvaluator.profile_from_screening(screening, @vocab)

      assert profile["personal"] == ["employer", "contractor"]
    end

    test "routes each code to the dimension the trees use it under" do
      screening = %{
        governed_actors: ["Org: Employer"],
        regions: ["England", "Scotland"],
        # premises/offshore are territorial in trees, despite the locations field
        locations: ["offshore", "premises"],
        materials: ["Asbestos"],
        processes: ["Construction Work"],
        sector: ["maritime"],
        certifications: ["iso_45001"]
      }

      profile = ApplicabilityEvaluator.profile_from_screening(screening, @vocab)

      assert profile["personal"] == ["employer"]
      assert Enum.sort(profile["territorial"]) == ["england", "offshore", "premises", "scotland"]
      assert Enum.sort(profile["material"]) == ["asbestos", "construction_work", "maritime"]
      # certifications are second-tier screening, not an evaluator dimension
      refute Enum.any?(Map.values(profile), &("iso_45001" in &1))
    end

    test "unknown codes fall back to the field's natural dimension" do
      screening = %{locations: ["laboratory"], governed_actors: ["Ind: User"]}

      profile = ApplicabilityEvaluator.profile_from_screening(screening, @vocab)

      assert profile["material"] == ["laboratory"]
      assert profile["personal"] == ["user"]
    end

    test "converts string-keyed profile (from JSON)" do
      screening = %{
        "governed_actors" => ["Org: Employer"],
        "regions" => ["England"],
        "locations" => [],
        "materials" => [],
        "processes" => [],
        "sector" => []
      }

      profile = ApplicabilityEvaluator.profile_from_screening(screening, @vocab)

      assert profile == %{"personal" => ["employer"], "territorial" => ["england"]}
    end

    test "empty profile produces empty map" do
      screening = %{governed_actors: [], regions: [], locations: [], materials: []}

      assert ApplicabilityEvaluator.profile_from_screening(screening, @vocab) == %{}
    end

    test "includes conditions (and legacy conditional key)" do
      profile =
        ApplicabilityEvaluator.profile_from_screening(
          %{conditions: ["at_work"], conditional: ["employees_gte_5"]},
          @vocab
        )

      assert Enum.sort(profile["conditional"]) == ["at_work", "employees_gte_5"]
    end

    test "routed profile matches an employer tree that the prefixed label never matched" do
      tree = %{"op" => "Match", "dimension" => "personal", "codes" => ["employer"]}

      profile =
        ApplicabilityEvaluator.profile_from_screening(
          %{governed_actors: ["Org: Employer"]},
          @vocab
        )

      assert %{applies: true} = ApplicabilityEvaluator.evaluate(tree, profile)
    end
  end
end
