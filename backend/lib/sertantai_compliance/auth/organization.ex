defmodule SertantaiCompliance.Auth.Organization do
  @moduledoc """
  Organization resource for multi-tenant data isolation.
  In a production setup, this would typically be synced from a centralized auth service.
  This starter demonstrates a read-only pattern, but you can modify it to support local organization management.
  """
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SertantaiCompliance.Api

  postgres do
    table("organizations")
    repo(SertantaiCompliance.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
    end

    attribute :slug, :string do
      allow_nil?(false)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :users, SertantaiCompliance.Auth.User
  end

  actions do
    defaults([:read])

    read :by_id do
      argument(:id, :uuid, allow_nil?: false)
      get?(true)
      filter(expr(id == ^arg(:id)))
    end

    read :by_slug do
      argument(:slug, :string, allow_nil?: false)
      get?(true)
      filter(expr(slug == ^arg(:slug)))
    end
  end

  code_interface do
    define(:read)
    define(:by_id, args: [:id])
    define(:by_slug, args: [:slug])
  end
end
