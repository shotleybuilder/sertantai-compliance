defmodule SertantaiCompliance.Legal.ControlMapping do
  @moduledoc """
  Read-only mirror of `control_mappings` owned by sertantai-legal.

  Join table linking controls to provisions (LAT sections). Accessed via
  shared database — no writes from this service.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("control_mappings")
    repo(SertantaiCompliance.Repo)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :control_id, :uuid do
      allow_nil?(false)
    end

    attribute :law_name, :string do
      allow_nil?(false)
    end

    attribute :section_id, :string do
      allow_nil?(false)
    end

    attribute(:short_ref, :string)
    attribute(:mapping_strength, :string)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
