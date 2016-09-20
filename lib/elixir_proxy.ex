defmodule ElixirProxy do
  import Plug.Conn

  @forbidden_headers ["content-length", "x-hal-zoom", "date", "connection", "etag", "accept-ranges", "transfer-encoding"]

  def start(_type, _argv) do
    IO.puts "Running ElixirProxy v#{ElixirProxy.Mixfile.project[:version]} with Cowboy on http://localhost:4000"
    res = Plug.Adapters.Cowboy.http(__MODULE__, [], port: 4000, compress: true)

    # Tiny hack until properly implemented Mix Tasks
    unless Code.ensure_loaded?(IEx) && IEx.started?, do: :timer.sleep(:infinity), else: res
  end

  def init(options), do: options

  def call(conn, _opts) do
    {:ok, req_body, conn} = Plug.Conn.read_body(conn)
    {headers, body, status_code} = HALRequest.zoom(conn.method, path(conn), req_body, conn.req_headers)
    %{conn | resp_headers: headers.hdrs |> prepare_headers(conn)}
    |> send_resp(status_code, body)
  end

  defp prepare_location(headers, url, conn) do
    {_, host} = conn.req_headers |> List.keyfind("host", 0)
    headers |> Dict.put("location", to_string(conn.scheme) <> "://" <> host <> URI.parse(url).path)
  end

  defp prepare_headers(headers, conn) do
    headers
    |> Enum.map(fn({k,v}) -> {k |> Atom.to_string, v} end)
    |> Enum.into(%{})
    |> fix_redirect(conn)
    |> Dict.put("x-hal-zoomed", "1")
    |> Dict.drop(@forbidden_headers)
    |> Dict.to_list
  end

  defp fix_redirect(%{"location" => loc} = headers, conn), do: headers |> prepare_location(loc, conn)
  defp fix_redirect(headers, _), do: headers

  defp path(conn) do
    base = "/" <> Enum.join(conn.path_info, "/")
    case conn.query_string do
      "" -> base
      qs -> base <> "?" <> qs
    end
  end
end
