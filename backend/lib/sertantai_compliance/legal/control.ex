defmodule SertantaiCompliance.Legal.Control do
  @moduledoc """
  Read-only mirror of Controls owned by sertantai-legal.

  AI-generated compliance controls derived from law provisions. Each control
  represents an operational mechanism that addresses obligations in a law.
  Accessed via the shared database. No create/update/destroy actions.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("controls")
    repo(SertantaiCompliance.Repo)
    migrate?(false)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    # Core identification
    attribute :law_name, :string do
      allow_nil?(false)
    end

    attribute :control_id, :string do
      allow_nil?(false)
    end

    attribute(:source_id, :string)
    attribute(:related_control_ids, :string)

    # Control content
    attribute(:title, :string)
    attribute(:description, :string)
    attribute(:what_it_checks, :string)

    # Classification
    attribute(:control_type, :string)
    attribute(:nature, :string)
    attribute(:domain, :string)
    attribute(:frequency, :string)

    # Distance and methods
    attribute(:info_distance, :string)
    attribute(:blast_radius, :string)
    attribute(:expected_touch_frequency, :string)

    # Provision linkage
    attribute(:linked_provisions, {:array, :string})
    attribute(:mapping_strength, :string)

    # Judgement and evidence
    attribute(:load_bearing_judgement, :string)
    attribute(:evidence_type_a, :string)
    attribute(:evidence_type_b, :string)
    attribute(:honest_limit, :string)

    # Status and tier
    attribute :status, :string do
      default("Planned")
    end

    attribute :tier, :string do
      default("Jurisdiction")
    end

    # Predicate flag
    attribute :is_predicate, :boolean do
      allow_nil?(false)
      default(false)
    end

    # Pipeline metadata
    attribute(:generation_model, :string)
    attribute(:base_hash, :string)

    # Timestamps
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
