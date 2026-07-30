defmodule SertantaiCompliance.Legal.SecondarySourceProvision do
  @moduledoc """
  Read-only mirror of `secondary_source_provisions` owned by sertantai-legal.

  Parsed structural provisions within a secondary source document. Accessed
  via shared database — no writes from this service.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("secondary_source_provisions")
    repo(SertantaiCompliance.Repo)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :section_id, :string do
      allow_nil?(false)
    end

    attribute :secondary_source_id, :uuid do
      allow_nil?(false)
    end

    attribute :source_id, :string do
      allow_nil?(false)
    end

    attribute(:sort_key, :string)
    attribute(:position, :integer)

    attribute :section_type, :atom do
      allow_nil?(false)

      constraints(
        one_of: [
          :volume,
          :part,
          :chapter,
          :section,
          :clause,
          :heading,
          :paragraph,
          :sub_paragraph,
          :schedule,
          :annex,
          :table,
          :figure,
          :note
        ]
      )
    end

    attribute(:depth, :integer)
    attribute(:hierarchy_path, :string)
    attribute(:heading, :string)
    attribute(:text, :string)

    attribute :text_source, :atom do
      allow_nil?(false)
      default(:full_text)
      constraints(one_of: [:full_text, :summary, :heading_only])
    end

    attribute(:drrp_types, {:array, :string})
    attribute(:actors, {:array, :map})
    attribute(:governed_actors, {:array, :string})
    attribute(:popimar, {:array, :string})
    attribute(:purposes, {:array, :string})
    attribute(:significance_overall, :string)
    attribute(:taxa_enriched_at, :utc_datetime_usec)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
