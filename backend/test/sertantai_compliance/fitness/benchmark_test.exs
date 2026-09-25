defmodule SertantaiCompliance.Fitness.BenchmarkTest do
  use ExUnit.Case, async: true

  alias SertantaiCompliance.Fitness.{Benchmark, Vocabulary}

  @vocab Vocabulary.from_rows([
           ["employer", "personal", 10, 5],
           ["local_authority", "personal", 10, 5],
           ["england", "territorial", 10, 5],
           ["premises", "territorial", 10, 5],
           ["asbestos", "material", 10, 5],
           ["building", "material", 10, 5],
           ["construction_work", "material", 10, 5],
           ["diving_operations", "material", 10, 5]
         ])

  @profile %{
    "governed_actors" => ["Org: Employer"],
    "regions" => ["England"],
    "materials" => ["asbestos"],
    "processes" => ["construction_work"]
  }

  defp m(dim, codes), do: %{"op" => "Match", "dimension" => dim, "codes" => codes}
  defp all(children), do: %{"op" => "And", "children" => children}

  defp law(name, tree),
    do: %{
      name: name,
      title_en: name,
      family: "F",
      geo_extent: "E+W",
      compiled_applicability: tree
    }

  defp run(laws, reference, law_status \\ %{}) do
    reference =
      Enum.map(reference, fn {name, status} ->
        %{law_name: name, status: status, source: "test"}
      end)

    Benchmark.run(reference, @profile, laws: laws, law_status: law_status, vocabulary: @vocab)
  end

  defp cause(result, name), do: Enum.find(result.rows, &(&1.law_name == name))

  test "agreement and screener-side causes" do
    laws = [
      law("both", all([m("personal", ["employer"]), m("material", ["asbestos"])])),
      law("says_no", m("personal", ["employer"])),
      law("territory_only", m("territorial", ["england"])),
      law("neither", m("material", ["diving_operations"]))
    ]

    result = run(laws, [{"both", "yes"}, {"says_no", "no"}])

    assert %{agreement: "both"} = cause(result, "both")
    assert %{agreement: "screener_only", cause: "register_says_no"} = cause(result, "says_no")

    assert %{agreement: "screener_only", cause: "territory_only_tree"} =
             cause(result, "territory_only")

    refute cause(result, "neither")
  end

  test "register-only causes found by what-if re-evaluation" do
    laws = [
      law("no_tree", nil),
      law("generic", all([m("personal", ["employer"]), m("material", ["building"])])),
      law("gov", all([m("personal", ["local_authority"]), m("material", ["asbestos"])])),
      # The profile's only material facts are asbestos and construction_work:
      # wholly within this disapplication, so it's a categorical exclusion.
      law(
        "not",
        all([
          m("personal", ["employer"]),
          %{"op" => "Not", "child" => m("material", ["asbestos", "construction_work"])}
        ])
      ),
      law(
        "material_miss",
        all([m("personal", ["employer"]), m("material", ["diving_operations"])])
      )
    ]

    result = run(laws, Enum.map(laws, &{&1.name, "yes"}))

    assert %{side: "tree", cause: "no_tree"} = cause(result, "no_tree")
    assert %{side: "tree", cause: "generic_code_gate"} = cause(result, "generic")
    assert %{side: "tree", cause: "gov_actor_gate"} = cause(result, "gov")

    assert %{
             side: "tree",
             cause: "disapplied_by_not",
             detail: "org wholly within Not: material:asbestos material:construction_work"
           } =
             cause(result, "not")

    assert %{
             side: "profile_or_tree",
             cause: "material_condition_miss",
             detail: "needs one of: diving_operations"
           } =
             cause(result, "material_miss")
  end

  test "referenced laws outside the corpus" do
    status = %{
      "revoked" => %{
        revoked: true,
        live: "❌ Revoked",
        country: "uk",
        is_making: true,
        title_en: "R",
        family: "F",
        geo_extent: "E"
      },
      "amending" => %{
        revoked: false,
        live: "✔ In force",
        country: "uk",
        is_making: false,
        title_en: "A",
        family: "F",
        geo_extent: "E"
      }
    }

    result =
      run(
        [],
        [{"revoked", "yes"}, {"amending", "yes"}, {"missing", "yes"}, {"ignored_no", "no"}],
        status
      )

    assert %{side: "register", cause: "revoked"} = cause(result, "revoked")
    assert %{side: "classification", cause: "not_making"} = cause(result, "amending")
    assert %{side: "legal_data", cause: "missing_record"} = cause(result, "missing")
    refute cause(result, "ignored_no")
  end

  test "summary counts agreement and evaluable agreement rate" do
    laws = [
      law("both", m("personal", ["employer"])),
      law("miss", m("material", ["diving_operations"]))
    ]

    %{summary: summary} = run(laws, [{"both", "yes"}, {"miss", "yes"}])

    assert summary.agreement == %{"both" => 1, "register_only" => 1}
    assert summary.evaluable_agreement_rate == 0.5
  end

  test "reference CSV round-trips" do
    path = Path.join(System.tmp_dir!(), "benchmark_ref_#{System.unique_integer([:positive])}.csv")
    rows = [%{law_name: "UK_a, with comma", status: "yes", source: "enhesa_import"}]

    Benchmark.write_reference!(rows, path)

    assert Benchmark.read_reference!(path) == rows
  end
end
