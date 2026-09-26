defmodule SertantaiComplianceWeb.AuthPlug do
  @moduledoc """
  JWT validation plug for sertantai-compliance.

  Validates EdDSA (Ed25519) Bearer tokens issued by sertantai-auth. The public
  key is fetched from auth's JWKS endpoint and cached by `JwksClient`.

  ## Conn Assigns

  On success, sets:
  - `conn.assigns.current_user_id` - UUID extracted from sub claim
  - `conn.assigns.organization_id` - Organization UUID from org_id claim
  - `conn.assigns.user_role` - Role string from role claim
  - `conn.assigns.jwt_claims` - Full decoded claims map
  """

  import Plug.Conn

  alias SertantaiCompliance.Auth.JwksClient

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case authenticate(conn) do
      {:ok, auth} ->
        # Error reports carry pseudonymous IDs only, never the email.
        Sentry.Context.set_user_context(%{id: auth.user_id})
        Sentry.Context.set_tags_context(%{organization_id: auth.organization_id})

        conn
        |> assign(:current_user_id, auth.user_id)
        |> assign(:organization_id, auth.organization_id)
        |> assign(:user_role, auth.claims["role"])
        |> assign(:jwt_claims, auth.claims)

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized", reason: reason}))
        |> halt()
    end
  end

  @doc """
  Verify the request's Bearer token without touching the conn. Used by the
  plug and by routes outside the `:auth` pipeline (the Electric proxy), which
  need the verified organisation to scope shapes themselves.
  """
  @spec authenticate(Plug.Conn.t()) ::
          {:ok, %{user_id: String.t(), organization_id: String.t(), claims: map()}}
          | {:error, String.t()}
  def authenticate(conn) do
    with {:ok, token} <- extract_token(conn),
         {:ok, claims} <- verify_token(token),
         {:ok, user_id} <- extract_user_id(claims),
         {:ok, org_id} <- extract_org_id(claims) do
      {:ok, %{user_id: user_id, organization_id: org_id, claims: claims}}
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, "Missing or invalid Authorization header"}
    end
  end

  defp verify_token(token) do
    case try_verify(token) do
      {:ok, _claims} = ok ->
        ok

      {:error, "Invalid token signature"} ->
        case JwksClient.refresh_sync() do
          {:ok, _jwk} -> try_verify(token)
          {:error, _} -> {:error, "Invalid token signature"}
        end

      {:error, _reason} = err ->
        err
    end
  end

  defp try_verify(token) do
    with {:ok, jwk} <- JwksClient.public_key() do
      case JOSE.JWT.verify_strict(jwk, ["EdDSA"], token) do
        {true, %JOSE.JWT{fields: claims}, _jws} ->
          validate_claims(claims)

        {false, _, _} ->
          {:error, "Invalid token signature"}
      end
    else
      {:error, :no_key} ->
        {:error, "Auth service unavailable (no signing key)"}
    end
  rescue
    _ -> {:error, "Malformed token"}
  end

  defp validate_claims(claims) do
    now = System.system_time(:second)

    cond do
      not is_integer(claims["exp"]) ->
        {:error, "Token missing expiry"}

      claims["exp"] < now ->
        {:error, "Token expired"}

      true ->
        {:ok, claims}
    end
  end

  defp extract_user_id(%{"sub" => "user?id=" <> user_id}), do: {:ok, user_id}
  defp extract_user_id(%{"sub" => sub}) when is_binary(sub), do: {:ok, sub}
  defp extract_user_id(_claims), do: {:error, "Token missing sub claim"}

  # Every compliance route is org-scoped: a token without a valid org_id is
  # rejected here rather than reaching queries with a nil organization.
  defp extract_org_id(%{"org_id" => org_id}) when is_binary(org_id) do
    case Ecto.UUID.cast(org_id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, "Token org_id is not a valid UUID"}
    end
  end

  defp extract_org_id(_claims), do: {:error, "Token missing org_id claim"}
end
