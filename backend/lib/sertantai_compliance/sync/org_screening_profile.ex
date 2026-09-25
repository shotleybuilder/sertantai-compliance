defmodule SertantaiCompliance.Sync.OrgScreeningProfile do
  @moduledoc """
  Organisation screening profile for deterministic applicability matching.

  Stores tag selections across fitness dimensions + geographic scope.
  Used by the auto-screener to match laws against the org's profile.
  Each org has exactly one profile (upsert on organization_id).
  """

  use Ash.Resource,
    domain: SertantaiCompliance.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("org_screening_profiles")
    repo(SertantaiCompliance.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :organization_id, :uuid do
      allow_nil?(false)
      description("Organization UUID from JWT — one profile per org")
    end

    # Geographic scope (primary filter — uses geo_region on laws)
    attribute :regions, {:array, :string} do
      default([])
      description("Geographic regions: England, Scotland, Wales, Northern Ireland, etc.")
    end

    # DRRP actor dimensions (matched against duty/rights/responsibility/power holders)
    attribute :governed_actors, {:array, :string} do
      default([])

      description(
        "Governed actors with duties/rights: Org: Employer, SC: Contractor, Ind: Employee, etc."
      )
    end

    attribute :government_actors, {:array, :string} do
      default([])

      description(
        "Government actors with responsibilities/powers: Gvt: Authority, Gvt: Minister, etc."
      )
    end

    # Fitness dimensions (secondary filter — matched against law fitness arrays)
    attribute :activities, {:array, :string} do
      default([])
      description("Legacy — use governed_actors/government_actors instead. Kept for migration.")
    end

    attribute :locations, {:array, :string} do
      default([])
      description("Physical site types: premises, offshore, ship, aircraft, mine, etc.")
    end

    attribute :materials, {:array, :string} do
      default([])

      description(
        "Substances/equipment: chemicals, explosives, asbestos, lead, pressure equipment, etc."
      )
    end

    attribute :processes, {:array, :string} do
      default([])
      description("Activities/operations: construction work, diving operations, gas work, etc.")
    end

    attribute :sector, {:array, :string} do
      default([])

      description(
        "Industry verticals: maritime, nuclear, water industry, offshore oil & gas, etc."
      )
    end

    # Second-tier screening dimensions (matched against secondary sources)
    attribute :certifications, {:array, :string} do
      default([])
      description("Management system certifications: iso_45001, iso_14001, iso_9001, etc.")
    end

    attribute :contract_requirements, {:array, :string} do
      default([])

      description(
        "Contractual requirement sets: jsp_375, cdm_client, etc. Drives JSP/contract-tier applicability."
      )
    end

    # Answers to conditional questions (GET /api/screening/questions), matched
    # against the `conditional` dimension of expression trees (e.g. at_work).
    attribute :conditions, {:array, :string} do
      default([])

      description(
        "Conditional facts that hold for the org, e.g. at_work. Codes come from GET /api/screening/questions."
      )
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_org, [:organization_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :organization_id,
        :regions,
        :governed_actors,
        :government_actors,
        :activities,
        :locations,
        :materials,
        :processes,
        :sector,
        :certifications,
        :contract_requirements,
        :conditions
      ])
    end

    update :update do
      accept([
        :regions,
        :governed_actors,
        :government_actors,
        :activities,
        :locations,
        :materials,
        :processes,
        :sector,
        :certifications,
        :contract_requirements,
        :conditions
      ])
    end

    update :patch do
      description("""
      Partially update a screening profile: only the fields given change, every
      other field keeps its value. Use this to add or correct a few values.
      """)

      accept([
        :regions,
        :governed_actors,
        :government_actors,
        :activities,
        :locations,
        :materials,
        :processes,
        :sector,
        :certifications,
        :contract_requirements,
        :conditions
      ])
    end

    create :upsert do
      description("""
      Create or fully replace an organisation's screening profile. Fields not
      given are reset to empty. Use :patch to change only some fields.
      """)

      accept([
        :organization_id,
        :regions,
        :governed_actors,
        :government_actors,
        :activities,
        :locations,
        :materials,
        :processes,
        :sector,
        :certifications,
        :contract_requirements,
        :conditions
      ])

      upsert?(true)
      upsert_identity(:unique_org)

      upsert_fields([
        :regions,
        :governed_actors,
        :government_actors,
        :activities,
        :locations,
        :materials,
        :processes,
        :sector,
        :certifications,
        :contract_requirements,
        :conditions
      ])
    end

    # Generic actions below are the machine-facing surface (REST today, MCP via
    # ash_ai in v0.2): descriptions are written for AI clients.

    action :vocabulary, :map do
      description("""
      Describe the screening vocabulary: how profiles are matched against laws,
      every settable profile field, and every code per dimension (personal,
      material, territorial, conditional) with the number of laws using it.
      Read this before setting a profile.
      """)

      run(fn _input, _context ->
        {:ok, SertantaiCompliance.Fitness.ProfileCheck.describe()}
      end)
    end

    action :check, :map do
      description("""
      Check a profile (full or partial, not saved) against the vocabulary.
      Returns valid: false with each value that cannot match any law and
      suggested codes, plus how values are routed to dimensions.
      """)

      argument :profile, :map do
        allow_nil?(false)
        description("Profile fields to check, e.g. %{\"materials\" => [\"asbestos\"]}")
      end

      run(fn input, _context ->
        {:ok, SertantaiCompliance.Fitness.ProfileCheck.check(input.arguments.profile)}
      end)
    end

    read :by_organization do
      argument(:organization_id, :uuid, allow_nil?: false)
      get?(true)
      filter(expr(organization_id == ^arg(:organization_id)))
    end
  end

  code_interface do
    define(:create, args: [:organization_id])
    define(:upsert)
    define(:update)
    define(:patch)
    define(:by_organization, args: [:organization_id])
    define(:destroy)
    define(:vocabulary)
    define(:check, args: [:profile])
  end
end
