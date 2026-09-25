defmodule SertantaiCompliance.Sync.ChangeDetectorTest do
  use ExUnit.Case, async: true

  alias SertantaiCompliance.Sync.ChangeDetector

  @in_force "✔ In force"
  @part "⭕ Part Revocation / Repeal"
  @revoked "❌ Revoked / Repealed / Abolished"

  defp law(name, attrs \\ []) do
    Map.merge(
      %{
        law_name: name,
        title: name,
        live: @in_force,
        amended_by: [],
        rescinded_by: [],
        in_corpus: true
      },
      Map.new(attrs)
    )
  end

  defp index(laws), do: Map.new(laws, &{&1.law_name, &1})

  defp diff(before, now), do: ChangeDetector.diff(index(before), index(now))

  describe "status/1" do
    test "Part Revocation / Repeal is partial, although it also says Repeal" do
      assert ChangeDetector.status(@part) == :part
      assert ChangeDetector.status(@revoked) == :revoked
      assert ChangeDetector.status(@in_force) == :in_force
      assert ChangeDetector.status(nil) == :in_force
    end
  end

  describe "diff/2" do
    test "no change, no result" do
      assert diff([law("A", amended_by: ["X"])], [law("A", amended_by: ["X"])]) == []
    end

    test "a new amending law" do
      assert [%{law_name: "A", effect: "amended", caused_by: ["Y"]}] =
               diff([law("A", amended_by: ["X"])], [law("A", amended_by: ["X", "Y"])])
    end

    test "a new revoking law with partial effect" do
      assert [%{effect: "part_revoked", caused_by: ["R"]}] =
               diff([law("A")], [law("A", live: @part, rescinded_by: ["R"])])
    end

    test "revocation in full is the outcome, whatever the cause" do
      assert [%{effect: "revoked", caused_by: ["R"]}] =
               diff([law("A", live: @part, rescinded_by: ["P"])], [
                 law("A", live: @revoked, rescinded_by: ["P", "R"], in_corpus: false)
               ])
    end

    test "an already revoked law is not re-reported" do
      revoked = law("A", live: @revoked, in_corpus: false)
      assert diff([revoked], [revoked]) == []
    end

    test "a law newly in the corpus (e.g. newly made)" do
      assert [%{law_name: "NEW", new_in_corpus: true, effect: nil}] = diff([], [law("NEW")])

      assert [%{new_in_corpus: true}] =
               diff([law("A", in_corpus: false)], [law("A", in_corpus: true)])
    end

    test "a law that isn't in the corpus doesn't become a new law" do
      assert diff([], [law("OLD", in_corpus: false)]) == []
    end
  end
end
