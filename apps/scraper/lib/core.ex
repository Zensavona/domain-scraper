defmodule Scraper.Core do
  alias HTTPoison

  def url_to_urls_and_domains(url) do
    domain = url |> domain_from_url
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body, headers: headers}} ->
        headers = headers |> Map.new
        if Map.get(headers, "Content-Type") do
          content_type = Map.get(headers, "Content-Type")
          case String.contains?(content_type, "html") do
            true ->
              links = Floki.find(body, "a") |> Floki.attribute("href") |> normalise_urls("http://#{domain}")
              urls = links
                |> Enum.reject(fn(l) -> domain_from_url(l) !== domain end)
                |> Enum.reject(fn(l) -> l == url end)
              domains = links |> Enum.reject(fn(l) -> domain_from_url(l) == domain end) |> Enum.map(&domain_from_url(&1))
              {:ok, urls, domains}
            _ ->
              {:error, url}
          end
        else
          {:error, url}
        end
      {:ok, %HTTPoison.Response{status_code: 301, headers: headers}} ->
        url = headers |> Enum.into(%{}) |> Map.get("Location")
        {:ok, [url], []}
      {:ok, %HTTPoison.Response{status_code: 302, headers: headers}} ->
        url = headers |> Enum.into(%{}) |> Map.get("Location")
        {:ok, [url], []}
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, url}
      {:ok, %HTTPoison.Response{status_code: 400}} ->
        {:error, url}
      {:error, %HTTPoison.Error{reason: _reason}} ->
        {:error, url}
      {:closed, _} ->
        {:error, url}
      :closed ->
        {:error, url}
      _ ->
        {:error, url}
    end
  end

  # private

  def check_domain(domain) do
    parsed = Domainatrex.parse(domain)
    domain = "#{Map.get(parsed, :domain)}.#{Map.get(parsed, :tld)}"
    IO.puts "[Core] Checking #{domain}"
    case HTTPoison.get(domain) do
      {:ok, _} ->
        :registered
      {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}} ->
        case Whois.lookup domain do
          {:ok, %Whois.Record{created_at: nil}} ->
            :available
          {:ok, _} ->
            :registered
          {:error, _} ->
            :error
        end
      _ ->
      :error
    end
  end

  defp domain_from_url(url) do
    host = URI.parse(url).host
    bits = Domainatrex.parse(host)
    "#{bits.domain}.#{bits.tld}"
  end
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
