defmodule SertantaiCompliance.Sync.LawChangeSnapshot do
  @moduledoc """
  The last-seen change state of each watched law, used by
  `SertantaiCompliance.Sync.ChangeDetector` to find what changed since the
  previous run.

  A law is watched if it is in any org's register or in the screening corpus.
  Each run diffs legal_register against these rows (new amending/revoking
  laws, status changes, laws newly in the corpus), raises events for the
  affected orgs, then updates the rows. The first run only records the
  baseline, so an org's change feed starts clean instead of replaying the
  whole history of its register.

  Global (not per org): a law's change is a fact about the law; which orgs
  hear about it is decided at detection time.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("law_change_snapshots")
    repo(SertantaiCompliance.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :law_name, :string do
      allow_nil?(false)
      description("legal_register.name")
    end

    attribute :live, :string do
      description(
        "legal_register.live at the last run, e.g. ✔ In force, ⭕ Part Revocation / Repeal"
      )
    end

    attribute :amended_by, {:array, :string} do
      default([])
      description("Amending laws seen so far (legal_register.amended_by)")
    end

    attribute :rescinded_by, {:array, :string} do
      default([])
      description("Revoking/repealing laws seen so far (legal_register.rescinded_by)")
    end

    attribute :in_corpus, :boolean do
      default(false)
      description("Whether the law was in the screening corpus (in-force UK Making law)")
    end

    update_timestamp(:snapshot_at)
  end

  identities do
    identity(:unique_law, [:law_name])
  end

  actions do
    defaults([:read])
  end
end
