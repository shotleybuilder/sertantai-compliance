defmodule SertantaiCompliance.Legal.AmendmentAnnotation do
  @moduledoc """
  Read-only mirror of Amendment Annotations owned by sertantai-legal.

  One row per legislative change annotation — links amendment footnotes
  (F-codes, C-codes, I-codes, E-codes) to affected legal article sections.
  Accessed via the shared database. No create/update/destroy actions.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("amendment_annotations")
    repo(SertantaiCompliance.Repo)
  end

  attributes do
    attribute :id, :string do
      primary_key?(true)
      allow_nil?(false)
      writable?(true)
    end

    attribute :country, :string do
      allow_nil?(false)
      default("uk")
    end

    attribute :law_id, :uuid do
      allow_nil?(false)
    end

    attribute :law_name, :string do
      allow_nil?(false)
    end

    attribute :code, :string do
      allow_nil?(false)
    end

    attribute :code_type, :atom do
      allow_nil?(false)
      constraints(one_of: [:amendment, :modification, :commencement, :extent_editorial])
    end

    attribute :source, :string do
      allow_nil?(false)
    end

    attribute :text, :string do
      allow_nil?(false)
    end

    attribute(:affected_sections, {:array, :string})

    # Timestamps
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
