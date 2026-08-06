defmodule SertantaiComplianceWeb.ScreeningEvaluateTest do
  @moduledoc """
  Integration tests for the evaluate and questions controller actions.

  These call the controller directly (bypassing router auth) and use the
  sandbox-wrapped test database. Since legal_register lives in the shared
  sertantai_legal_dev database (not in the test DB), these tests validate
  controller logic using mock data inserted via raw SQL.
  """
  use SertantaiComplianceWeb.ConnCase

  alias SertantaiCompliance.Repo

  @org_id "00000000-0000-0000-0000-000000000001"
  @user_id "00000000-0000-0000-0000-000000000099"

  defp authed_conn(conn) do
    conn
    |> Plug.Conn.put_private(:phoenix_endpoint, SertantaiComplianceWeb.Endpoint)
    |> Plug.Conn.assign(:current_user_id, @user_id)
    |> Plug.Conn.assign(:organization_id, @org_id)
    |> Plug.Conn.assign(:user_role, "admin")
    |> Plug.Conn.put_req_header("content-type", "application/json")
  end

  defp ensure_legal_register_table! do
    # Create a minimal legal_register table if it doesn't exist in the test DB.
    # This mirrors only the columns needed by the evaluate/questions endpoints.
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS legal_register (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT,
      title_en TEXT,
      family TEXT,
      country TEXT DEFAULT 'uk',
      live TEXT DEFAULT '✔ In force',
      is_making BOOLEAN DEFAULT true,
      compiled_applicability JSONB,
      significance_rating TEXT,
      significance_score FLOAT,
      geo_extent TEXT,
      duty_holder JSONB,
      power_holder JSONB,
      rights_holder JSONB,
      responsibility_holder JSONB,
      fitness_entities TEXT[]
    )
    """)
  end

  defp insert_test_law!(name, opts) do
    compiled = Keyword.get(opts, :compiled_applicability)
    family = Keyword.get(opts, :family, "OH&S")
    title = Keyword.get(opts, :title, "Test Law #{name}")
    duty_holder = Keyword.get(opts, :duty_holder)

    compiled_json = if compiled, do: Jason.encode!(compiled), else: nil
    duty_json = if duty_holder, do: Jason.encode!(duty_holder), else: nil

    Repo.query!(
      """
      INSERT INTO legal_register (name, title_en, family, country, live, is_making,
        compiled_applicability, significance_rating, significance_score,
        geo_extent, duty_holder)
      VALUES ($1, $2, $3, 'uk', '✔ In force', true, $4::jsonb, 'HIGH', 10.0,
        'E+W+S+NI', $5::jsonb)
      ON CONFLICT DO NOTHING
      """,
      [name, title, family, compiled_json, duty_json]
    )
  end

  setup %{conn: _conn} do
    ensure_legal_register_table!()

    # Insert test laws with various compiled_applicability trees
    insert_test_law!("TEST_employer_law",
      compiled_applicability: %{
        "op" => "Match",
        "dimension" => "personal",
        "codes" => ["employer"],
        "confidence" => 0.95
      },
      duty_holder: %{"values" => ["Org: Employer"]}
    )

    insert_test_law!("TEST_contractor_law",
      compiled_applicability: %{
        "op" => "And",
        "children" => [
          %{"op" => "Match", "dimension" => "personal", "codes" => ["contractor"]},
          %{"op" => "Match", "dimension" => "territorial", "codes" => ["scotland"]}
        ]
      }
    )

    insert_test_law!("TEST_conditional_law",
      compiled_applicability: %{
        "op" => "Conditional",
        "condition" => %{
          "op" => "Match",
          "dimension" => "conditional",
          "codes" => ["employees_gte_5"]
        },
        "then" => %{
          "op" => "Match",
          "dimension" => "personal",
          "codes" => ["employer"],
          "confidence" => 0.85
        }
      }
    )

    insert_test_law!("TEST_no_tree_law",
      compiled_applicability: nil,
      family: "Environment"
    )

    :ok
  end

  describe "evaluate/2" do
    test "evaluates corpus with profile override and returns structured response", %{conn: conn} do
      resp =
        conn
        |> authed_conn()
        |> SertantaiComplianceWeb.ScreeningController.evaluate(%{
          "profile" => %{
            "governed_actors" => ["employer"],
            "regions" => ["England"],
            "locations" => [],
            "materials" => [],
            "processes" => [],
            "sector" => []
          }
        })

      assert %{"matches" => matches, "summary" => summary} = json_response(resp, 200)

      assert is_list(matches)
      assert is_integer(summary["total_making_laws"])
      assert is_integer(summary["evaluated"])
      assert is_integer(summary["not_evaluable"])
      assert summary["not_evaluable"] >= 1
      assert summary["profile_completeness"] == 0.4

      # Find our test employer law — should match
      employer_match = Enum.find(matches, fn m -> m["law_name"] == "TEST_employer_law" end)
      assert employer_match != nil
      assert employer_match["applies"] == true
      assert employer_match["confidence"] == 0.95
      assert length(employer_match["match_reasons"]) >= 1
      assert employer_match["current_status"] == "unreviewed"

      # Contractor+Scotland law should not match (we're employer in England)
      contractor_match = Enum.find(matches, fn m -> m["law_name"] == "TEST_contractor_law" end)
      assert contractor_match != nil
      assert contractor_match["applies"] == false

      # No-tree law should appear with applies=false, confidence=0.0
      no_tree = Enum.find(matches, fn m -> m["law_name"] == "TEST_no_tree_law" end)
      assert no_tree != nil
      assert no_tree["applies"] == false
      assert no_tree["confidence"] == 0.0
    end

    test "empty profile returns zero completeness and no matches", %{conn: conn} do
      resp =
        conn
        |> authed_conn()
        |> SertantaiComplianceWeb.ScreeningController.evaluate(%{
          "profile" => %{
            "governed_actors" => [],
            "regions" => [],
            "locations" => [],
            "materials" => [],
            "processes" => [],
            "sector" => []
          }
        })

      assert %{"summary" => summary} = json_response(resp, 200)
      assert summary["profile_completeness"] == 0.0
      assert summary["profile_dimensions"] == []
      assert summary["matches"]["total"] == 0
    end

    test "applying matches sorted before non-applying", %{conn: conn} do
      resp =
        conn
        |> authed_conn()
        |> SertantaiComplianceWeb.ScreeningController.evaluate(%{
          "profile" => %{
            "governed_actors" => ["employer"],
            "regions" => ["England"],
            "locations" => [],
            "materials" => [],
            "processes" => [],
            "sector" => []
          }
        })

      assert %{"matches" => matches} = json_response(resp, 200)

      if length(matches) > 1 do
        applying = Enum.take_while(matches, fn m -> m["applies"] end)
        non_applying = Enum.drop(matches, length(applying))
        assert Enum.all?(non_applying, fn m -> not m["applies"] end)
      end
    end

    test "actor_summary populated from duty_holder JSONB", %{conn: conn} do
      resp =
        conn
        |> authed_conn()
        |> SertantaiComplianceWeb.ScreeningController.evaluate(%{
          "profile" => %{
            "governed_actors" => ["employer"],
            "regions" => [],
            "locations" => [],
            "materials" => [],
            "processes" => [],
            "sector" => []
          }
        })

      assert %{"matches" => matches} = json_response(resp, 200)

      employer_match = Enum.find(matches, fn m -> m["law_name"] == "TEST_employer_law" end)
      assert employer_match != nil
      assert "Org: Employer" in employer_match["actor_summary"]["duties"]
    end
  end

  describe "questions/2" do
    test "extracts conditional codes from corpus trees", %{conn: conn} do
      resp =
        conn
        |> authed_conn()
        |> SertantaiComplianceWeb.ScreeningController.questions(%{})

      assert %{"questions" => questions} = json_response(resp, 200)
      assert is_list(questions)

      # Our test data has one law with employees_gte_5 conditional
      gte5 = Enum.find(questions, fn q -> q["code"] == "employees_gte_5" end)
      assert gte5 != nil
      assert gte5["dimension"] == "conditional"
      assert gte5["laws_affected"] >= 1
      assert gte5["text"] == "Do you have 5 or more employees?"
    end
  end
end
