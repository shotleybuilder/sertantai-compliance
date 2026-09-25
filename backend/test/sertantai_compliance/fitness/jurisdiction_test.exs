defmodule SertantaiCompliance.Fitness.JurisdictionTest do
  use ExUnit.Case, async: true

  alias SertantaiCompliance.Fitness.{Jurisdiction, Screener}

  doctest Jurisdiction

  describe "excluded_nation/2" do
    test "NI legislation is excluded for a GB-only org" do
      assert Jurisdiction.excluded_nation("UK_nisr_1997_195", ["england", "scotland", "wales"]) ==
               "northern_ireland"
    end

    test "a parent jurisdiction covers the nation" do
      assert Jurisdiction.excluded_nation("UK_nisr_1997_195", ["united_kingdom"]) == nil
      assert Jurisdiction.excluded_nation("UK_ssi_2004_428", ["great_britain"]) == nil
      assert Jurisdiction.excluded_nation("UK_wsi_2001_2283", ["england_and_wales"]) == nil
    end

    test "Scottish and Welsh legislation follow the same rule" do
      assert Jurisdiction.excluded_nation("UK_asp_2005_13", ["england"]) == "scotland"
      assert Jurisdiction.excluded_nation("UK_anaw_2017_2", ["england", "scotland"]) == "wales"
      assert Jurisdiction.excluded_nation("UK_asp_2005_13", ["scotland"]) == nil
    end

    test "UK-wide legislation is never excluded" do
      assert Jurisdiction.excluded_nation("UK_uksi_1999_3242", ["england"]) == nil
      assert Jurisdiction.excluded_nation("UK_ukpga_1974_37", ["northern_ireland"]) == nil
    end

    test "place types don't count as jurisdiction, and no jurisdiction means no exclusion" do
      assert Jurisdiction.excluded_nation("UK_nisr_1997_195", ["premises"]) == nil
      assert Jurisdiction.excluded_nation("UK_nisr_1997_195", []) == nil

      assert Jurisdiction.excluded_nation("UK_nisr_1997_195", ["england", "premises"]) ==
               "northern_ireland"
    end
  end

  test "Screener excludes a devolved law even when its tree matches" do
    # The real UK_nisr_1997_195 tree: a place type (premises) satisfies it
    tree = %{
      "op" => "Or",
      "children" => [
        %{
          "op" => "And",
          "children" => [
            %{"op" => "Match", "dimension" => "material", "codes" => ["licence"]},
            %{"op" => "Match", "dimension" => "territorial", "codes" => ["northern_ireland"]}
          ]
        },
        %{"op" => "Match", "dimension" => "territorial", "codes" => ["premises"]}
      ]
    }

    laws = [
      %{name: "UK_nisr_1997_195", compiled_applicability: tree},
      %{name: "UK_uksi_1997_1", compiled_applicability: tree}
    ]

    [ni, gb] = Screener.screen(%{"territorial" => ["england", "wales", "premises"]}, laws)

    assert %{applies: false, excluded: "jurisdiction:northern_ireland", reasons: []} = ni
    assert %{applies: true, excluded: nil} = gb
  end
end
