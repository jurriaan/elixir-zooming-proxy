defmodule HALRequest do
  use HTTPoison.Base

  def process_url(url), do: "http://localhost:1234" <> url

  def process_headers(headers), do: Enum.reduce(headers, %{}, fn({k,v}, dict) -> Dict.put(dict, String.downcase(k), v) end)

  def zoom(method, url, body, headers \\ %{}, depth \\ 0), do: request(method, url, body, headers) |> zoom(depth + 1)

  defp zoomable?(res), do: Dict.has_key?(res.headers, "x-hal-zoom") && String.contains?(res.headers["content-type"], "json")

  defp zoom({:ok, res}, depth), do: {res.headers, zoom_body(res, depth, zoomable?(res)), res.status_code}

  defp zoom_body(response, depth = 1, _zoomable = true), do: response.body |> json_decode |> embed(response.headers, depth) |> :jiffy.encode
  defp zoom_body(response, _depth = 1, _zoomable = false), do: response.body
  defp zoom_body(response, _depth, _zoomable = false), do: response.body |> json_decode
  defp zoom_body(response, depth, _zoomable = true), do: response.body |> json_decode |> embed(response.headers, depth)

  defp embed(body, headers, depth), do: Dict.put(body, "_embedded", get_embeds(body, headers["x-hal-zoom"] |> String.split, depth))

  defp get_embeds(body, zooms, depth) do
    zooms
    |> Enum.filter(&(Dict.has_key?(body["_links"], &1)))
    |> Parallel.map_reduce(Dict.get(body, "_embedded", %{}), fn(el) ->
        body["_links"][el] |> process_links(el, depth)
      end, fn({key, json}, ac) ->
        Dict.put(ac, key, json)
      end)
  end

  defp process_links(links, el, depth) when is_map(links), do: {el, links |> embed_link(depth)}
  defp process_links(links, el, depth), do: {el, links |> Parallel.map(&(embed_link(&1, depth)))}

  defp embed_link(%{"href" => link}, depth), do: elem(zoom("GET", URI.parse(link).path, "", %{}, depth), 1)

  defp json_decode(data), do: :jiffy.decode(data, [:return_maps])
end
