defmodule SertantaiComplianceWeb.HealthControllerTest do
  use SertantaiComplianceWeb.ConnCase

  test "GET /health reports the release version", %{conn: conn} do
    body = conn |> get("/health") |> json_response(200)

    assert body["status"] == "ok"
    assert body["version"] == Application.spec(:sertantai_compliance, :vsn) |> to_string()
    assert body["version"] =~ ~r/^\d+\.\d+\.\d+/
  end
end
