defmodule SertantaiComplianceWeb.ErrorTrackingTest do
  # Sets the global JWKS test key, so not async.
  use SertantaiComplianceWeb.ConnCase, async: false

  alias SertantaiComplianceWeb.ErrorTracking

  @org "c075d56b-8420-4408-b695-ccfbc1ba15ec"

  describe "scrubbing" do
    test "token-like query params are masked, others kept" do
      conn = Plug.Test.conn(:get, "/auth/callback?token=eyJhbGci.secret&next=%2Fbrowse&code=abc")
      url = ErrorTracking.scrub_url(conn)

      refute url =~ "eyJhbGci"
      refute url =~ "abc"
      assert URI.decode_query(URI.parse(url).query)["next"] == "/browse"
    end

    test "nested body params are masked" do
      conn =
        :post
        |> Plug.Test.conn("/api/x", %{
          "profile" => %{"access_token" => "t0k", "sector" => "defence"}
        })
        |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:urlencoded], pass: ["*/*"]))

      body = ErrorTracking.scrub_body(conn)

      assert body["profile"]["sector"] == "defence"
      refute body["profile"]["access_token"] == "t0k"
    end
  end

  describe "an error report from an authenticated request" do
    setup do
      jwk = JOSE.JWK.generate_key({:okp, :Ed25519})
      :ok = SertantaiCompliance.Auth.JwksClient.set_test_key(JOSE.JWK.to_public(jwk))

      Sentry.Test.setup_sentry()
      %{jwk: jwk}
    end

    test "carries user and org IDs but no token, email or IP", %{conn: conn, jwk: jwk} do
      claims = %{
        "sub" => "user?id=u1",
        "email" => "someone@example.com",
        "org_id" => @org,
        "exp" => System.system_time(:second) + 600
      }

      {_, token} = jwk |> JOSE.JWT.sign(%{"alg" => "EdDSA"}, claims) |> JOSE.JWS.compact()

      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> put_req_header("x-forwarded-for", "203.0.113.7")
      |> get("/api/screening/profile", %{"token" => token})

      # The endpoint ran in this process, so its context applies to the next report.
      Sentry.capture_message("probe")

      assert [event] = Sentry.Test.pop_sentry_reports()
      assert event.user[:id] == "u1"
      assert event.tags[:organization_id] == @org
      assert event.release == Mix.Project.config()[:version]

      report = inspect(event)
      refute report =~ token
      refute report =~ "someone@example.com"
      refute report =~ "203.0.113.7"
    end
  end
end
