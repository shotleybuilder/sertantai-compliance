defmodule SertantaiComplianceWeb.ElectricProxyControllerTest do
  @moduledoc """
  Access control for the Electric shape proxy. These requests are rejected
  before any call to Electric or the auth Gatekeeper.
  """
  use SertantaiComplianceWeb.ConnCase, async: false

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

  describe "org scoping is enforced by compliance, not taken from the client" do
    @org_a "c075d56b-8420-4408-b695-ccfbc1ba15ec"
    @org_b "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

    setup do
      for {k, v} <- [
            test_mode: true,
            auth_url: "http://auth.test",
            electric_url: "http://electric.test"
          ] do
        previous = Application.get_env(:sertantai_compliance, k)
        Application.put_env(:sertantai_compliance, k, v)

        on_exit(fn ->
          if previous == nil,
            do: Application.delete_env(:sertantai_compliance, k),
            else: Application.put_env(:sertantai_compliance, k, previous)
        end)
      end

      jwk = JOSE.JWK.generate_key({:okp, :Ed25519})
      :ok = SertantaiCompliance.Auth.JwksClient.set_test_key(JOSE.JWK.to_public(jwk))

      # Gatekeeper approves and (like the real one) echoes the client's where
      Req.Test.stub(SertantaiComplianceWeb.GatekeeperClient, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        shape = Jason.decode!(body)["shape"]
        Req.Test.json(conn, %{"status" => "success", "shape" => shape})
      end)

      # Electric: record the query the proxy forwards
      test_pid = self()

      Req.Test.stub(SertantaiComplianceWeb.ElectricProxyController, fn conn ->
        send(test_pid, {:electric_query, URI.decode_query(conn.query_string)})
        Plug.Conn.send_resp(conn, 200, "[]")
      end)

      %{jwk: jwk}
    end

    defp bearer(jwk, org_id) do
      claims = %{
        "sub" => "user?id=u1",
        "org_id" => org_id,
        "exp" => System.system_time(:second) + 600
      }

      {_, token} = jwk |> JOSE.JWT.sign(%{"alg" => "EdDSA"}, claims) |> JOSE.JWS.compact()
      "Bearer " <> token
    end

    defp shape(conn, jwk, params) do
      conn
      |> put_req_header("authorization", bearer(jwk, @org_a))
      |> get(
        "/api/electric/v1/shape",
        Map.merge(%{"table" => "org_applicabilities", "offset" => "-1"}, params)
      )
    end

    test "a widening where ('... OR true') is replaced by the token's org", %{
      conn: conn,
      jwk: jwk
    } do
      conn = shape(conn, jwk, %{"where" => "organization_id = '#{@org_a}' OR true"})

      assert conn.status == 200
      assert_received {:electric_query, query}
      assert query["where"] == "organization_id = '#{@org_a}'"
      assert query["table"] == "org_applicabilities"
    end

    test "another org's id in the where is ignored", %{conn: conn, jwk: jwk} do
      shape(conn, jwk, %{"where" => "organization_id = '#{@org_b}'"})

      assert_received {:electric_query, query}
      assert query["where"] == "organization_id = '#{@org_a}'"
    end

    test "subset__* filters are dropped; handle/offset pass through", %{conn: conn, jwk: jwk} do
      shape(conn, jwk, %{"subset__where" => "true", "handle" => "h1", "offset" => "0_0"})

      assert_received {:electric_query, query}
      refute Map.has_key?(query, "subset__where")
      assert query["handle"] == "h1"
      assert query["offset"] == "0_0"
    end

    test "an invalid token never reaches the Gatekeeper or Electric", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not-a-jwt")
        |> get("/api/electric/v1/shape", %{"table" => "org_applicabilities", "offset" => "-1"})

      assert conn.status == 401
      refute_received {:electric_query, _}
    end
  end
end
