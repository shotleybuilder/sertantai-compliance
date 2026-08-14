defmodule SertantaiCompliance.Legal.LegislativeDefinition do
  @moduledoc """
  Read-only mirror of `legislative_definitions` owned by sertantai-legal.

  Contains legal definitions extracted from UK legislation. A term may have
  different definitions across laws (e.g. "workplace" is defined in 17 SIs).
  Accessed via shared database — no writes from this service.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("legislative_definitions")
    repo(SertantaiCompliance.Repo)
    migrate?(false)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :law_name, :string do
      allow_nil?(false)
    end

    attribute :term, :string do
      allow_nil?(false)
    end

    attribute(:term_welsh, :string)

    attribute :definition, :string do
      allow_nil?(false)
    end

    attribute(:section_id, :string)

    attribute(:scope, :string)

    attribute :references_other_law, :boolean do
      allow_nil?(false)
      default(false)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
