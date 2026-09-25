defmodule SertantaiCompliance.Fitness.VocabularyTest do
  use ExUnit.Case, async: true

  alias SertantaiCompliance.Fitness.Vocabulary

  doctest Vocabulary

  @vocab Vocabulary.from_rows([
           ["employer", "personal", 161, 60],
           ["premises", "territorial", 308, 100],
           ["radioactive", "material", 1, 1],
           ["ionising_radiation", "material", 8, 4],
           ["evidence", "material", 1, 1],
           ["diving_operations", "material", 28, 12]
         ])

  describe "normalise/1" do
    test "strips nested taxonomy prefixes" do
      assert Vocabulary.normalise("SC: C: Principal Designer") == "principal_designer"

      assert Vocabulary.normalise("Gvt: Agency: Health and Safety Executive") ==
               "health_and_safety_executive"
    end

    test "leaves plain codes alone" do
      assert Vocabulary.normalise("diving_operations") == "diving_operations"
    end
  end

  describe "from_rows/1" do
    test "a code used under two dimensions resolves to the most-used" do
      vocab = Vocabulary.from_rows([["ship", "territorial", 50, 30], ["ship", "material", 2, 2]])

      assert vocab["ship"].dimension == "territorial"
    end
  end

  describe "lookup/2" do
    test "finds prefixed actor labels by their bare code" do
      assert {:ok, %{dimension: "personal"}} = Vocabulary.lookup("Org: Employer", @vocab)
    end

    test "unknown values" do
      assert Vocabulary.lookup("laboratory", @vocab) == :unknown
    end
  end

  describe "suggest/3" do
    test "suggests codes sharing a word" do
      codes = Vocabulary.suggest("radioactive_materials", @vocab) |> Enum.map(& &1.code)

      assert "radioactive" in codes
    end

    test "does not suggest spelling coincidences" do
      refute "evidence" in (Vocabulary.suggest("defence", @vocab) |> Enum.map(& &1.code))
    end
  end

  describe "route/3" do
    test "routes known codes by tree dimension and reports unknowns" do
      result = Vocabulary.route(["premises", "laboratory"], @vocab, "material")

      assert result.dimensions == %{"territorial" => ["premises"], "material" => ["laboratory"]}
      assert result.unknown == ["laboratory"]
    end
  end
end
