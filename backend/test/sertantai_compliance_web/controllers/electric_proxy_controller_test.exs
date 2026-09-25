defmodule SertantaiComplianceWeb.ElectricProxyControllerTest do
  @moduledoc """
  Access control for the Electric shape proxy. These requests are rejected
  before any call to Electric or the auth Gatekeeper.
  """
  use SertantaiComplianceWeb.ConnCase

  @org_tables ~w(org_applicabilities organization_locations location_screenings)

  describe "GET /api/electric/v1/shape" do
    test "org tables require auth", %{conn: conn} do
      for table <- @org_tables do
        conn = get(conn, "/api/electric/v1/shape", %{"table" => table, "offset" => "-1"})
        assert json_response(conn, 401)["error"] == "Authentication required"
      end
    end

    # Regression: a made-up handle used to skip auth and leak every org's rows
    # (Electric answers a mismatched handle with the shape for the given params).
    test "a handle does not bypass auth for org tables", %{conn: conn} do
      for table <- @org_tables do
        conn =
          get(conn, "/api/electric/v1/shape", %{
            "table" => table,
            "offset" => "-1",
            "handle" => "made-up-handle",
            "where" => "true"
          })

        assert json_response(conn, 401)["error"] == "Authentication required"
      end
    end

    test "missing table is rejected", %{conn: conn} do
      assert json_response(get(conn, "/api/electric/v1/shape"), 400)
    end
  end

  describe "DELETE /api/electric/v1/shape" do
    test "org tables require auth", %{conn: conn} do
      conn = delete(conn, "/api/electric/v1/shape?table=org_applicabilities")
      assert json_response(conn, 401)["error"] == "Authentication required"
    end

    test "unknown tables are rejected", %{conn: conn} do
      conn = delete(conn, "/api/electric/v1/shape?table=users")
      assert json_response(conn, 400)
    end
  end
end
