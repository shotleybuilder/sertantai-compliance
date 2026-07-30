defmodule SertantaiCompliance.Legal.ArtefactTemplate do
  @moduledoc """
  Read-only mirror of `artefact_templates` owned by sertantai-legal.

  Describes a concrete evidence artefact (document, record, certificate)
  that satisfies an evidence pattern. Accessed via shared database — no
  writes from this service.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("artefact_templates")
    repo(SertantaiCompliance.Repo)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :evidence_pattern_id, :uuid do
      allow_nil?(false)
    end

    attribute :title, :string do
      allow_nil?(false)
    end

    attribute(:artefact_type, :string)
    attribute(:artefact_class, :string)
    attribute(:what_it_proves, :string)
    attribute(:source, :string)
    attribute(:likelihood_ratio, :string)
    attribute(:recommended_frequency, :string)
    attribute(:evidence_by_design, :boolean)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
