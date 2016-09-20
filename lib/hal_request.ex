defmodule HALRequest do
  use HTTPotion.Base

  def process_url(url), do: "http://localhost:3000" <> url

  def process_response_headers(headers) do
    Enum.into(headers, %{}, fn { k, v } ->
      key = k |> to_string |> String.downcase
      value = v |> to_string
      {key, value}
    end)
  end

  def zoom(method, url, body, headers \\ %{}, depth \\ 0) do
    request(method, url, [headers: headers, body: body]) |> zoom_resp(headers, depth + 1, method == :get)
  end

  defp zoomable?(res), do: !!res.headers["x-hal-zoom"] && String.contains?(res.headers["content-type"], "json")

  defp zoom_resp(res = %HTTPotion.Response{}, req_headers, depth, do_zoom), do: {res.headers, zoom_body(res, req_headers, depth, do_zoom && zoomable?(res)), res.status_code}
  # defp zoom_resp(%HTTPotion.ErrorResponse{}, _, _), do: {%{}, "Backend error", 502}

  defp zoom_body(response, req_headers, depth = 1, _zoomable = true), do: response.body |> json_decode |> embed(response.headers, req_headers, depth) |> :jiffy.encode([:use_nil])
  defp zoom_body(response, req_headers, depth, _zoomable = true), do: response.body |> json_decode |> embed(response.headers, req_headers, depth)
  defp zoom_body(response, _, _depth = 1, _zoomable = false), do: response.body
  defp zoom_body(response, _, _, _), do: response.body |> json_decode

  defp embed(body, headers, req_headers, depth) do
    embeds = get_embeds(body, headers["x-hal-zoom"] |> String.split, req_headers, depth)
    case map_size(embeds) do
      0 -> body
      _ ->Map.put(body, "_embedded", embeds)
    end
  end

  defp get_embeds(body, zooms, req_headers, depth) do
    zooms
    |> Enum.filter(&(Map.has_key?(body["_links"], &1)))
    |> Parallel.map(fn(el) ->
        body["_links"][el] |> process_links(el, req_headers, depth)
    end)
    |> Enum.reject(fn {_, val} -> val == nil end)
    |> Enum.into(Map.get(body, "_embedded", %{}))
  end

  defp process_links(links, el, req_headers, depth) when is_map(links), do: {el, links |> embed_link(req_headers, depth)}
  defp process_links(links, el, req_headers, depth), do: {el, links |> Parallel.map(&(embed_link(&1, req_headers, depth)))}

  defp embed_link(%{"href" => link}, req_headers, depth) do
    url = URI.parse(link)
    host = if URI.default_port(url.scheme) == url.port, do: url.host, else: url.host <> ":" <> to_string(url.port)
    req_host = Enum.find_value(req_headers, fn {k, v} -> if k == "host", do: v end)

    cond do
      host == req_host ->
        elem(zoom(:get, url.path, "", req_headers, depth), 1)
      whitelisted(Enum.reverse(String.split(host, "."))) ->
        json_decode(HTTPotion.get(url, headers: [host: host]).body)
      true ->
        nil
    end
  end

  def whitelisted(["org", "example"]), do: true
  def whitelisted(["com", "example"]), do: true
  def whitelisted(_), do: false

  defp json_decode(data), do: :jiffy.decode(data, [:return_maps, :use_nil])
end
