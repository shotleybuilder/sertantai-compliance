defmodule SertantaiComplianceWeb.ScreeningComplianceMetricsTest do
  @moduledoc "GET /api/screening/compliance-metrics (#28)."
  use SertantaiComplianceWeb.ConnCase

  alias SertantaiComplianceWeb.ScreeningController

  @org_id "00000000-0000-0000-0000-000000000004"

  defp authed_conn(conn) do
    conn
    |> Plug.Conn.put_private(:phoenix_endpoint, SertantaiComplianceWeb.Endpoint)
    |> Plug.Conn.assign(:organization_id, @org_id)
  end

  test "returns empty metrics for an org with none", %{conn: conn} do
    conn = conn |> authed_conn() |> ScreeningController.compliance_metrics(%{})

    assert %{"compliant" => 0, "non_compliant" => 0, "actions_open" => 0} =
             json_response(conn, 200)
  end
end
