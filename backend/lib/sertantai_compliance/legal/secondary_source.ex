defmodule SertantaiCompliance.Legal.SecondarySource do
  @moduledoc """
  Read-only mirror of `secondary_sources` owned by sertantai-legal.

  Document-level record for ACoPs, standards, JSPs, guidance notes, and
  industry codes. Accessed via shared database — no writes from this service.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("secondary_sources")
    repo(SertantaiCompliance.Repo)
    migrate?(false)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :source_type, :atom do
      allow_nil?(false)
      constraints(one_of: [:acop, :guidance, :standard, :jsp, :industry_code])
    end

    attribute :source_id, :string do
      allow_nil?(false)
    end

    attribute :title, :string do
      allow_nil?(false)
    end

    attribute :issuer, :string do
      allow_nil?(false)
    end

    attribute :legal_weight, :atom do
      allow_nil?(false)

      constraints(
        one_of: [:reverse_burden, :regard_had_to, :contractual, :state_of_art, :best_practice]
      )
    end

    attribute :status, :atom do
      allow_nil?(false)
      default(:current)
      constraints(one_of: [:current, :withdrawn, :superseded])
    end

    attribute(:edition, :string)
    attribute(:effective_date, :date)
    attribute(:parent_source_id, :uuid)
    attribute(:supersedes_id, :uuid)
    attribute(:source_url, :string)

    attribute :structure_type, :atom do
      constraints(one_of: [:volumes, :parts, :clauses, :sections])
    end

    attribute :metadata, :map do
      default(%{})
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
