defmodule SertantaiCompliance.Legal.EvidencePattern do
  @moduledoc """
  Read-only mirror of `evidence_patterns` owned by sertantai-legal.

  Captures the evidence strategy for a control — what to look for, how to
  verify compliance, and when to check. Accessed via shared database — no
  writes from this service.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("evidence_patterns")
    repo(SertantaiCompliance.Repo)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :law_name, :string do
      allow_nil?(false)
    end

    attribute :control_id, :string do
      allow_nil?(false)
    end

    attribute(:control_title, :string)
    attribute(:needs_judgement, :boolean)
    attribute(:judgement_rationale, :string)
    attribute(:recommended_method, :string)
    attribute(:basis_guidance, :string)
    attribute(:discriminating_question, :string)
    attribute(:drift_signal, :string)
    attribute(:drift_conditions, :string)
    attribute(:voi_quadrant, :string)
    attribute(:voi_rationale, :string)
    attribute(:evidence_standard, :string)
    attribute(:recommended_interval, :string)
    attribute(:sample_size_guidance, :string)
    attribute(:staleness_tolerance, :string)
    attribute(:nature_strategy, :string)
    attribute(:generation_model, :string)
    attribute(:base_hash, :string)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
