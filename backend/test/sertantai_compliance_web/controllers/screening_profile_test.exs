defmodule SertantaiComplianceWeb.ScreeningProfileTest do
  @moduledoc """
  Profile API: replace (PUT), partial update (PATCH), check, vocabulary.

  Calls the controller directly (bypassing router auth). The vocabulary is
  derived from expression trees in a minimal sandboxed legal_register table.
  """
  use SertantaiComplianceWeb.ConnCase

  alias SertantaiCompliance.Repo
  alias SertantaiCompliance.Sync.OrgScreeningProfile
  alias SertantaiComplianceWeb.ScreeningController

  @org_id "00000000-0000-0000-0000-000000000002"

  defp authed_conn(conn) do
    conn
    |> Plug.Conn.put_private(:phoenix_endpoint, SertantaiComplianceWeb.Endpoint)
    |> Plug.Conn.assign(:current_user_id, "00000000-0000-0000-0000-000000000099")
    |> Plug.Conn.assign(:organization_id, @org_id)
    |> Plug.Conn.assign(:user_role, "admin")
  end

  setup do
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS legal_register (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT, title_en TEXT, family TEXT, country TEXT DEFAULT 'uk',
      live TEXT DEFAULT '✔ In force', is_making BOOLEAN DEFAULT true,
      compiled_applicability JSONB, significance_rating TEXT, significance_score FLOAT,
      geo_extent TEXT, duty_holder JSONB, power_holder JSONB, rights_holder JSONB,
      responsibility_holder JSONB, fitness_entities TEXT[]
    )
    """)

    tree = %{
      "op" => "And",
      "children" => [
        %{"op" => "Match", "dimension" => "personal", "codes" => ["employer"]},
        %{"op" => "Match", "dimension" => "territorial", "codes" => ["premises", "england"]},
        %{"op" => "Match", "dimension" => "material", "codes" => ["diving_operations"]},
        %{"op" => "Match", "dimension" => "conditional", "codes" => ["at_work"]}
      ]
    }

    Repo.query!(
      "INSERT INTO legal_register (name, compiled_applicability) VALUES ('TEST_profile_law', $1)",
      # A map, not Jason.encode!/1: Postgrex encodes it as a JSON object (an
      # encoded string would be stored as a JSON string scalar).
      [tree]
    )

    :ok
  end

  defp put_profile(conn, params),
    do: conn |> authed_conn() |> ScreeningController.upsert_profile(params)

  defp patch_profile(conn, params),
    do: conn |> authed_conn() |> ScreeningController.patch_profile(params)

  describe "PUT /profile" do
    test "stores every field, including certifications and conditions", %{conn: conn} do
      body =
        conn
        |> put_profile(%{
          "governed_actors" => ["Org: Employer"],
          "certifications" => ["iso_45001"],
          "contract_requirements" => ["jsp_375"],
          "conditions" => ["at_work"]
        })
        |> json_response(200)

      assert body["certifications"] == ["iso_45001"]
      assert body["contract_requirements"] == ["jsp_375"]
      assert body["conditions"] == ["at_work"]
      assert body["warnings"] == []
    end

    test "replaces: fields not given are reset", %{conn: conn} do
      put_profile(conn, %{"materials" => ["diving_operations"], "regions" => ["England"]})

      body = conn |> put_profile(%{"regions" => ["England"]}) |> json_response(200)

      assert body["materials"] == []
      assert body["regions"] == ["England"]
    end

    test "stores unknown values but warns with suggestions", %{conn: conn} do
      body = conn |> put_profile(%{"processes" => ["diving_operation"]}) |> json_response(200)

      assert body["processes"] == ["diving_operation"]

      assert [%{"field" => "processes", "value" => "diving_operation", "suggestions" => [s | _]}] =
               body["warnings"]

      assert s["code"] == "diving_operations"
    end

    test "?strict=true rejects unknown values and saves nothing", %{conn: conn} do
      conn = put_profile(conn, %{"strict" => "true", "materials" => ["laboratory"]})

      assert %{"valid" => false, "unknown" => [%{"value" => "laboratory"}]} =
               json_response(conn, 422)

      assert {:error, _} = OrgScreeningProfile.by_organization(@org_id)
    end
  end

  describe "PATCH /profile" do
    test "changes only the fields given", %{conn: conn} do
      put_profile(conn, %{"governed_actors" => ["Org: Employer"], "regions" => ["England"]})

      body = conn |> patch_profile(%{"materials" => ["diving_operations"]}) |> json_response(200)

      assert body["materials"] == ["diving_operations"]
      assert body["governed_actors"] == ["Org: Employer"]
      assert body["regions"] == ["England"]
    end

    test "creates the profile when the org has none", %{conn: conn} do
      body = conn |> patch_profile(%{"regions" => ["England"]}) |> json_response(200)

      assert body["regions"] == ["England"]
    end
  end

  describe "POST /profile/check" do
    test "routes values to tree dimensions without saving", %{conn: conn} do
      body =
        conn
        |> authed_conn()
        |> ScreeningController.check_profile(%{
          "profile" => %{"locations" => ["premises"], "governed_actors" => ["Org: Employer"]}
        })
        |> json_response(200)

      assert body["valid"] == true
      assert body["routed"]["territorial"] == ["premises"]
      assert body["routed"]["personal"] == ["employer"]
      assert {:error, _} = OrgScreeningProfile.by_organization(@org_id)
    end
  end

  describe "GET /vocabulary" do
    test "describes fields and tree codes per dimension", %{conn: conn} do
      body =
        conn |> authed_conn() |> ScreeningController.vocabulary(%{}) |> json_response(200)

      assert body["about"] =~ "dimension"
      assert %{"code" => "premises", "law_count" => 1} in body["dimensions"]["territorial"]
      assert %{"code" => "at_work", "law_count" => 1} in body["dimensions"]["conditional"]

      conditions = Enum.find(body["fields"], &(&1["name"] == "conditions"))
      assert conditions["screened"] == true
      assert conditions["default_dimension"] == "conditional"
    end
  end
end
