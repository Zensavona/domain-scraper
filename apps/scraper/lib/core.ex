defmodule Scraper.Core do
  alias HTTPoison

  def url_to_urls_and_domains(url) do
    domain = url |> domain_from_url
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        links = Floki.find(body, "a") |> Floki.attribute("href") |> normalise_urls("http://#{domain}")

        urls = links
          |> Enum.reject(fn(l) -> domain_from_url(l) !== domain end)
          |> Enum.reject(fn(l) -> l == url end)
        domains = links |> Enum.reject(fn(l) -> domain_from_url(l) == domain end) |> Enum.map(&domain_from_url(&1))

        {:ok, urls, domains}
      {:ok, %HTTPoison.Response{status_code: 301, headers: headers}} ->
        url = headers |> Enum.into(%{}) |> Map.get("Location")
        {:ok, [url], []}
      {:ok, %HTTPoison.Response{status_code: 302, headers: headers}} ->
        url = headers |> Enum.into(%{}) |> Map.get("Location")
        {:ok, [url], []}
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        # don't worry 'bout it
        IO.puts "Not found :("
        {:ok, [], []}
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
      {:closed, _} ->
        {:error, "closed on #{url}"}
      :closed ->
        {:error, "closed on #{url}"}
    end
  end

  def check_domain(domain) do
    case HTTPoison.get(domain) do
      {:ok, %HTTPoison.Response{status_code: code}} when code == 200 or code == 301 or code == 302 ->
        IO.puts "#{domain} valid :("
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        IO.puts "Success! #{domain} 404'd"
      {:error, %HTTPoison.Error{reason: :nxdomain}} ->
        IO.puts "nxdomain error for #{domain}"
    end
  end

  # private

  defp domain_from_url(url), do: url |> String.split("/") |> Enum.fetch!(2)
  defp remove_double_slashes_from_url(url) do
    parts = String.split(url, "//", parts: 2)
    replacement = parts |> Enum.fetch!(1) |> String.replace("//", "/")

    parts |> List.replace_at(1, replacement) |> Enum.join("//")
  end
  defp normalise_urls(urls, base_url) do
    urls
      |> Enum.reject(&String.contains?(&1, "mailto:"))
      |> Enum.map(fn(u) -> if !String.contains?(u, "http"), do: "#{base_url}/#{u}", else: u end)
      |> Enum.map(&remove_double_slashes_from_url/1)
  end
end
