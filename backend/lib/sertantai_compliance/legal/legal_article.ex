defmodule SertantaiCompliance.Legal.LegalArticle do
  @moduledoc """
  Read-only mirror of Legal Articles owned by sertantai-legal.

  Provides access to parsed legal article text (LAT) data — one row per
  structural section of a law. Accessed via the shared database.
  No create/update/destroy actions.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("legal_articles")
    repo(SertantaiCompliance.Repo)
  end

  attributes do
    attribute :section_id, :string do
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

    # Ordering
    attribute :sort_key, :string do
      allow_nil?(false)
    end

    attribute :position, :integer do
      allow_nil?(false)
    end

    # Structure
    attribute :section_type, :atom do
      allow_nil?(false)

      constraints(
        one_of: [
          :title,
          :part,
          :chapter,
          :heading,
          :section,
          :sub_section,
          :article,
          :sub_article,
          :paragraph,
          :sub_paragraph,
          :schedule,
          :commencement,
          :table,
          :note,
          :signed
        ]
      )
    end

    attribute(:hierarchy_path, :string)

    attribute :depth, :integer do
      allow_nil?(false)
    end

    # Structural location
    attribute(:part, :string)
    attribute(:chapter, :string)
    attribute(:heading_group, :string)
    attribute(:provision, :string)
    attribute(:paragraph, :string)
    attribute(:sub_paragraph, :string)
    attribute(:schedule, :string)

    # Content
    attribute :text, :string do
      allow_nil?(false)
    end

    attribute :language, :string do
      allow_nil?(false)
      default("en")
    end

    attribute(:extent_code, :string)

    # Annotation counts
    attribute(:amendment_count, :integer)
    attribute(:modification_count, :integer)
    attribute(:commencement_count, :integer)
    attribute(:extent_count, :integer)
    attribute(:editorial_count, :integer)

    # DRRP and actors
    attribute(:drrp_types, {:array, :string})
    attribute(:governed_actors, {:array, :string})
    attribute(:government_actors, {:array, :string})
    attribute(:actors, {:array, :map})

    # Extraction metadata
    attribute(:extraction_method, :string)
    attribute(:holder_inferred_from, :string)
    attribute(:ancestor_distance, :integer)

    # Duty classification
    attribute(:duty_family, :string)
    attribute(:duty_sub_type, :string)
    attribute(:clause_refined, :string)

    # Taxonomy
    attribute(:purposes, {:array, :string})
    attribute(:popimar, {:array, :string})
    attribute(:taxa_confidence, :float)
    attribute(:taxa_enriched_at, :utc_datetime_usec)

    # Significance
    attribute(:significance_scope_duty_bearer, :string)
    attribute(:significance_scope_protected_class, :string)
    attribute(:significance_gravity, :string)
    attribute(:significance_strength, :string)
    attribute(:significance_hierarchy, :string)
    attribute(:significance_confidence, :float)
    attribute(:significance_overall, :string)

    # Embedding
    attribute(:embedding, {:array, :float})
    attribute(:embedding_model, :string)
    attribute(:embedded_at, :utc_datetime_usec)

    # Tokenization
    attribute(:token_ids, {:array, :integer})
    attribute(:tokenizer_model, :string)

    # Legacy
    attribute(:legacy_id, :string)

    # Timestamps
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])
  end
end
