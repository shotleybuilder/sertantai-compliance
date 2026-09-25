defmodule SertantaiComplianceWeb.AuthPlugTest do
  use SertantaiComplianceWeb.ConnCase, async: false

  alias SertantaiCompliance.Auth.JwksClient
  alias SertantaiComplianceWeb.AuthPlug

  @org_id "c075d56b-8420-4408-b695-ccfbc1ba15ec"

  setup do
    jwk = JOSE.JWK.generate_key({:okp, :Ed25519})
    :ok = JwksClient.set_test_key(JOSE.JWK.to_public(jwk))
    %{jwk: jwk}
  end

  defp token(jwk, claims) do
    base = %{"sub" => "user?id=00000000-0000-0000-0000-000000000099", "exp" => now() + 600}

    {_, token} =
      jwk
      |> JOSE.JWT.sign(%{"alg" => "EdDSA"}, Map.merge(base, claims))
      |> JOSE.JWS.compact()

    token
  end

  defp now, do: System.system_time(:second)

  defp call(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer " <> token)
    |> AuthPlug.call([])
  end

  test "valid token assigns user and organisation", %{conn: conn, jwk: jwk} do
    conn = call(conn, token(jwk, %{"org_id" => @org_id, "role" => "owner"}))

    refute conn.halted
    assert conn.assigns.organization_id == @org_id
    assert conn.assigns.current_user_id == "00000000-0000-0000-0000-000000000099"
  end

  test "a token without org_id is rejected", %{conn: conn, jwk: jwk} do
    conn = call(conn, token(jwk, %{}))

    assert conn.halted
    assert conn.status == 401
    assert Jason.decode!(conn.resp_body)["reason"] == "Token missing org_id claim"
  end

  test "a non-UUID org_id is rejected", %{conn: conn, jwk: jwk} do
    conn = call(conn, token(jwk, %{"org_id" => "not-a-uuid"}))

    assert conn.status == 401
  end

  test "expired and foreign-signed tokens are rejected", %{conn: conn, jwk: jwk} do
    expired = token(jwk, %{"org_id" => @org_id, "exp" => now() - 10})
    assert call(conn, expired).status == 401

    other = JOSE.JWK.generate_key({:okp, :Ed25519})
    assert call(build_conn(), token(other, %{"org_id" => @org_id})).status == 401
  end
end
