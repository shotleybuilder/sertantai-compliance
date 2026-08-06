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
      assert result.confidence == 1.0
      assert length(result.reasons) == 1

      [reason] = result.reasons
      assert reason.dimension == "personal"
      assert reason.matched_codes == ["employer"]
      assert reason.node_confidence == 1.0
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

  # ── profile_from_screening/1 ───────────────────────────────────

  describe "profile_from_screening/1" do
    test "converts atom-keyed profile" do
      screening = %{
        governed_actors: ["Org: Employer", "SC: Contractor"],
        government_actors: [],
        regions: ["England", "Scotland"],
        locations: ["offshore"],
        materials: ["Asbestos"],
        processes: ["Construction Work"],
        sector: ["maritime"],
        certifications: ["iso_45001"]
      }

      profile = ApplicabilityEvaluator.profile_from_screening(screening)

      assert "personal" in Map.keys(profile)
      assert "territorial" in Map.keys(profile)
      assert "material" in Map.keys(profile)

      # Personal = governed + government actors, normalised
      assert "org:_employer" in profile["personal"]
      assert "sc:_contractor" in profile["personal"]

      # Territorial = regions, normalised
      assert "england" in profile["territorial"]
      assert "scotland" in profile["territorial"]

      # Material = locations + materials + processes + sector, normalised
      assert "offshore" in profile["material"]
      assert "asbestos" in profile["material"]
      assert "construction_work" in profile["material"]
      assert "maritime" in profile["material"]
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

      profile = ApplicabilityEvaluator.profile_from_screening(screening)

      assert "personal" in Map.keys(profile)
      assert "territorial" in Map.keys(profile)
      # Empty arrays don't create dimension keys
      refute Map.has_key?(profile, "material")
    end

    test "empty profile produces empty map" do
      screening = %{
        governed_actors: [],
        government_actors: [],
        regions: [],
        locations: [],
        materials: [],
        processes: [],
        sector: []
      }

      profile = ApplicabilityEvaluator.profile_from_screening(screening)

      assert profile == %{}
    end

    test "includes conditional dimension if present" do
      screening = %{
        governed_actors: ["Org: Employer"],
        regions: [],
        locations: [],
        materials: [],
        processes: [],
        sector: [],
        conditional: ["employees_gte_5", "at_work"]
      }

      profile = ApplicabilityEvaluator.profile_from_screening(screening)

      assert "conditional" in Map.keys(profile)
      assert "employees_gte_5" in profile["conditional"]
    end
  end
end
