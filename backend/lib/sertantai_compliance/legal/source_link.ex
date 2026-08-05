defmodule SertantaiCompliance.Legal.SourceLink do
  @moduledoc """
  Read-only mirror of `source_links` owned by sertantai-legal.

  Many-to-many link between secondary sources and primary legislation.
  Accessed via shared database — no writes from this service.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("source_links")
    repo(SertantaiCompliance.Repo)
    migrate?(false)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :secondary_source_id, :uuid do
      allow_nil?(false)
    end

    attribute(:secondary_section_id, :string)

    attribute :law_name, :string do
      allow_nil?(false)
    end

    attribute(:section_id, :string)

    attribute :link_type, :atom do
      allow_nil?(false)

      constraints(
        one_of: [:approved_under, :implements, :references, :supplements, :superseded_by]
      )
    end

    attribute(:notes, :string)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
