defmodule SertantaiComplianceWeb.ErrorTracking do
  @moduledoc """
  Request scrubbing for error reports sent to GlitchTip (Sentry-compatible).

  Error reports leave the server, so they carry no credentials and no client
  IP (nor the forwarding headers that hold it). Sentry's defaults already drop the `authorization` header, cookies and
  `password`/`secret` params; this adds the token-like params that sign-in
  and the Electric proxy use.
  """

  alias Sentry.PlugContext

  @scrubbed "*********"
  # nginx passes the client IP in these
  @client_ip_headers ~w(x-forwarded-for x-real-ip forwarded)
  @sensitive_params ~w(token access_token refresh_token jwt id_token code secret password)

  @doc "Options for `Sentry.PlugContext` in the endpoint."
  @spec plug_context_opts() :: keyword()
  def plug_context_opts do
    [
      body_scrubber: {__MODULE__, :scrub_body},
      header_scrubber: {__MODULE__, :scrub_headers},
      url_scrubber: {__MODULE__, :scrub_url},
      remote_address_reader: {__MODULE__, :no_remote_address}
    ]
  end

  @spec scrub_body(Plug.Conn.t()) :: map()
  def scrub_body(conn), do: conn |> PlugContext.default_body_scrubber() |> scrub_map()

  @spec scrub_headers(Plug.Conn.t()) :: map()
  def scrub_headers(conn),
    do: conn |> PlugContext.default_header_scrubber() |> Map.drop(@client_ip_headers)

  @spec scrub_url(Plug.Conn.t()) :: String.t()
  def scrub_url(conn) do
    base = Plug.Conn.request_url(%{conn | query_string: ""})

    case conn.query_string do
      "" -> base
      query -> base <> "?" <> (query |> URI.decode_query() |> scrub_map() |> URI.encode_query())
    end
  end

  @spec no_remote_address(Plug.Conn.t()) :: nil
  def no_remote_address(_conn), do: nil

  defp scrub_map(%_{} = struct), do: struct

  defp scrub_map(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        if String.downcase(key) in @sensitive_params,
          do: {key, @scrubbed},
          else: {key, scrub_map(value)}

      {key, value} ->
        {key, scrub_map(value)}
    end)
  end

  defp scrub_map(list) when is_list(list), do: Enum.map(list, &scrub_map/1)
  defp scrub_map(value), do: value
end
