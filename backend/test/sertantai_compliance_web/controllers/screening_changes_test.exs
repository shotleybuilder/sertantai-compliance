defmodule SertantaiComplianceWeb.ScreeningChangesTest do
  @moduledoc "Change feed API: summary counts and CSV export."
  use SertantaiComplianceWeb.ConnCase

  alias SertantaiCompliance.Sync.ApplicabilityEvent
  alias SertantaiComplianceWeb.ScreeningController

  @org_id "00000000-0000-0000-0000-000000000003"

  defp authed_conn(conn) do
    conn
    |> Plug.Conn.put_private(:phoenix_endpoint, SertantaiComplianceWeb.Endpoint)
    |> Plug.Conn.assign(:current_user_id, "00000000-0000-0000-0000-000000000099")
    |> Plug.Conn.assign(:organization_id, @org_id)
    |> Plug.Conn.assign(:user_role, "admin")
  end

  defp log!(attrs) do
    {:ok, event} =
      ApplicabilityEvent.log(
        Map.merge(
          %{
            organization_id: @org_id,
            actor: "sertantai",
            source: "change_detection",
            status_before: "yes",
            status_after: "yes"
          },
          attrs
        )
      )

    event
  end

  setup do
    log!(%{
      law_name: "UK_ssi_2004_428",
      event: "law_amended",
      materiality: "moderate",
      review_due_date: ~D[2026-11-24],
      metadata: %{
        "title" => "Amended Regs, with comma",
        "change_type" => "amended",
        "caused_by" => ["UK_ssi_2005_344", "UK_ssi_2006_1"]
      }
    })

    log!(%{
      law_name: "UK_nisr_1997_195",
      event: "new_law_available",
      status_before: nil,
      status_after: "unreviewed",
      materiality: "major",
      review_due_date: ~D[2026-10-25],
      metadata: %{"title" => "New Regs", "tier" => "strong"}
    })

    # Not part of the feed any more
    log!(%{law_name: "UK_x", event: "match_score_changed", materiality: "minor", metadata: %{}})

    :ok
  end

  test "summary counts law_amended and ignores match_score_changed", %{conn: conn} do
    body = conn |> authed_conn() |> ScreeningController.changes_summary(%{}) |> json_response(200)

    assert body["by_event"]["law_amended"] == 1
    assert body["by_event"]["new_law_available"] == 1
    assert body["by_event"]["match_score_changed"] == 0
  end

  test "export returns pending changes as CSV, soonest review first", %{conn: conn} do
    conn = conn |> authed_conn() |> ScreeningController.changes_export(%{})

    assert response_content_type(conn, :csv) =~ "text/csv"
    assert get_resp_header(conn, "content-disposition") |> hd() =~ "legal-changes-"

    [header | rows] = conn.resp_body |> SertantaiCompliance.CSV.parse_string(skip_headers: false)

    assert hd(header) == "law_name"
    assert [["UK_nisr_1997_195" | new_law], ["UK_ssi_2004_428" | amended]] = rows
    assert Enum.at(new_law, 1) == "new_law_available"
    assert Enum.at(new_law, 4) == "strong"
    # title with a comma survives quoting; caused_by joined with spaces
    assert Enum.slice(amended, 0, 4) ==
             [
               "Amended Regs, with comma",
               "law_amended",
               "amended",
               "UK_ssi_2005_344 UK_ssi_2006_1"
             ]

    assert Enum.at(amended, 7) == "pending"
  end
end
