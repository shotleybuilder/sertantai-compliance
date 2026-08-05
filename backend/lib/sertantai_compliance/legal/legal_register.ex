defmodule SertantaiCompliance.Legal.LegalRegister do
  @moduledoc """
  Read-only mirror of the Legal Register owned by sertantai-legal.

  Provides access to multi-jurisdiction legal/regulatory reference data
  via the shared database. No create/update/destroy actions — this
  service only reads.
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("legal_register")
    repo(SertantaiCompliance.Repo)
    migrate?(false)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    # Jurisdiction
    attribute :country, :string do
      allow_nil?(false)
      default("uk")
    end

    attribute :jurisdiction, :string do
      allow_nil?(false)
      default("uk")
    end

    # Classification
    attribute(:family, :string)
    attribute(:family_ii, :string)

    # Identification
    attribute(:name, :string)
    attribute(:title_en, :string)
    attribute(:year, :integer)
    attribute(:number, :string)

    attribute :number_int, :integer do
      writable?(false)
    end

    attribute(:acronym, :string)
    attribute(:old_style_number, :string)

    # Type
    attribute(:type_desc, :string)
    attribute(:type_code, :string)
    attribute(:type_class, :string)

    # Domain
    attribute(:domain, {:array, :string})

    # Status
    attribute(:live, :string)
    attribute(:live_description, :string)
    attribute(:live_from_changes, :string)

    # Geography
    attribute(:geo_extent, :string)
    attribute(:geo_region, {:array, :string})
    attribute(:geo_detail, :string)
    attribute(:md_restrict_extent, :string)

    # Holders (JSONB)
    attribute(:duty_holder, :map)
    attribute(:power_holder, :map)
    attribute(:rights_holder, :map)
    attribute(:responsibility_holder, :map)

    # Purpose and function (JSONB)
    attribute(:purpose, :map)
    attribute(:function, :map)

    # POPIMAR (JSONB)
    attribute(:popimar, :map)
    attribute(:popimar_details, :map)

    # SI codes (JSONB)
    attribute(:si_code, :map)
    attribute(:enacted_si_codes, :map)
    attribute(:enacted_families, :map)

    # Subjects (JSONB)
    attribute(:md_subjects, :map)

    # Roles
    attribute(:role, {:array, :string})
    attribute(:role_gvt, :map)
    attribute(:role_details, :map)
    attribute(:role_gvt_details, :map)

    # Duty types
    attribute(:duty_type, :map)
    attribute(:duty_type_article, :string)
    attribute(:article_duty_type, :string)

    # Obligations (JSONB)
    attribute(:duties, :map)
    attribute(:rights, :map)
    attribute(:responsibilities, :map)
    attribute(:powers, :map)

    # Fitness
    attribute(:fitness_entities, {:array, :string})
    attribute(:fitness_scope_dimensions, {:array, :string})
    attribute(:fitness_mention_count, :integer)
    attribute(:fitness_applies_count, :integer)
    attribute(:fitness_disapplies_count, :integer)

    # Compiled applicability (JSONB)
    attribute(:compiled_applicability, :map)

    # Significance
    attribute(:significance_rating, :string)
    attribute(:significance_score, :float)
    attribute(:significance_high_count, :integer)
    attribute(:significance_medium_count, :integer)
    attribute(:significance_low_count, :integer)
    attribute(:significance_total_obligations, :integer)
    attribute(:significance_parts, {:array, :map})

    attribute :has_fitness, :boolean do
      allow_nil?(false)
      writable?(false)
    end

    # Tags and descriptions
    attribute(:tags, {:array, :string})
    attribute(:md_description, :string)
    attribute(:explanatory_note, :string)

    # Document stats
    attribute(:md_total_paras, :integer)
    attribute(:md_body_paras, :integer)
    attribute(:md_schedule_paras, :integer)
    attribute(:md_attachment_paras, :integer)
    attribute(:md_images, :integer)

    # Amending relationships
    attribute(:amending, {:array, :string})
    attribute(:amended_by, {:array, :string})
    attribute(:rescinding, {:array, :string})
    attribute(:rescinded_by, {:array, :string})
    attribute(:enacting, {:array, :string})
    attribute(:enacted_by, {:array, :string})
    attribute(:enacted_by_meta, {:array, :map})

    # Boolean flags
    attribute(:is_amending, :boolean)
    attribute(:is_rescinding, :boolean)
    attribute(:is_enacting, :boolean)
    attribute(:is_making, :boolean)
    attribute(:is_commencing, :boolean)

    # Making classification
    attribute(:making_confidence, :float)
    attribute(:making_classification, :string)
    attribute(:making_review, :string)
    attribute(:making_review_at, :utc_datetime_usec)
    attribute(:making_detection_tier, :integer)
    attribute(:making_detection_signals, :map)

    # Amendment stats (emoji-prefixed source columns)
    attribute :stats_self_affects_count, :integer do
      source(:"🔺🔻_stats_self_affects_count")
    end

    attribute :stats_self_affects_count_per_law_detailed, :string do
      source(:"🔺🔻_stats_self_affects_count_per_law_detailed")
    end

    attribute :amending_stats_affects_count, :integer do
      source(:"🔺_stats_affects_count")
    end

    attribute :amending_stats_affected_laws_count, :integer do
      source(:"🔺_stats_affected_laws_count")
    end

    attribute :amended_by_stats_affected_by_count, :integer do
      source(:"🔻_stats_affected_by_count")
    end

    attribute :amended_by_stats_affected_by_laws_count, :integer do
      source(:"🔻_stats_affected_by_laws_count")
    end

    attribute :rescinding_stats_rescinding_laws_count, :integer do
      source(:"🔺_stats_rescinding_laws_count")
    end

    attribute :rescinded_by_stats_rescinded_by_laws_count, :integer do
      source(:"🔻_stats_rescinded_by_laws_count")
    end

    attribute :affects_stats_per_law, :map do
      source(:"🔺_affects_stats_per_law")
    end

    attribute :rescinding_stats_per_law, :map do
      source(:"🔺_rescinding_stats_per_law")
    end

    attribute :affected_by_stats_per_law, :map do
      source(:"🔻_affected_by_stats_per_law")
    end

    attribute :rescinded_by_stats_per_law, :map do
      source(:"🔻_rescinded_by_stats_per_law")
    end

    # Change logs
    attribute(:amending_change_log, :string)
    attribute(:amended_by_change_log, :string)
    attribute(:record_change_log, {:array, :map})

    # Timestamps
    create_timestamp(:created_at)
    update_timestamp(:updated_at)

    # Dates
    attribute(:md_date, :date)

    attribute :md_date_year, :integer do
      writable?(false)
    end

    attribute :md_date_month, :integer do
      writable?(false)
    end

    attribute(:md_made_date, :date)
    attribute(:md_enactment_date, :date)
    attribute(:md_coming_into_force_date, :date)
    attribute(:md_dct_valid_date, :date)
    attribute(:md_modified, :date)
    attribute(:latest_amend_date, :date)
    attribute(:latest_change_date, :date)
    attribute(:latest_rescind_date, :date)

    # LAT stats
    attribute :lat_count, :integer do
      allow_nil?(false)
      default(0)
      writable?(false)
    end

    attribute :latest_lat_updated_at, :utc_datetime_usec do
      writable?(false)
    end

    # Source
    attribute(:source_url, :string)
  end

  actions do
    defaults([:read])
  end
end
