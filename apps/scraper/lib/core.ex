defmodule Scraper.Core do
  alias HTTPoison

  def url_to_urls_and_domains(url) do
    domain = url |> domain_from_url
    case HTTPoison.get(url, [], hackney: [pool: :first_pool]) do
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
    case HTTPoison.get(domain, [], hackney: [pool: :first_pool]) do
      {:ok, _} ->
        {:registered, nil}
      {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}} ->
        case Whois.lookup domain do
          {:ok, %Whois.Record{created_at: nil}} ->
            case check_from_dnsimple(domain) do
              :available ->
                {:available, lookup_stats(domain)}
              :registered ->
                {:registered, nil}
              :error ->
                {:error, nil}
            end
          {:ok, _} ->
            {:registered, nil}
          {:error, _} ->
            {:error, nil}
        end
      _ ->
      {:error, nil}
    end
  end

  def lookup_stats(domain) do
    case HTTPoison.get("https://seo-rank.my-addr.com/api2/moz+alexa+sr+maj+spam/#{Application.get_env(:scraper, :seo_rank_api_key)}/#{domain}", [], hackney: [pool: :first_pool]) do
      {:ok, %{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, data} ->
            data |> Enum.filter(fn({_k, v}) -> Float.parse("#{v}") !== :error end) |> Enum.map(fn({k, v}) -> {k, "#{v}"} end) |> Enum.into(%{})
          _ ->
            %{}
        end
      {:error, response} ->
        %{}
      _ ->
        %{}
    end
  end

  def check_from_dnsimple(domain) do
    case HTTPoison.get("https://api.dnsimple.com/v2/#{Application.get_env(:scraper, :dnsimple_account_number)}/registrar/domains/#{domain}/check", ["Authorization": "Bearer #{Application.get_env(:scraper, :dnsimple_api_key)}", "Accept": "Application/json; Charset=utf-8"], hackney: [pool: :first_pool]) do
      {:ok, %{status_code: 200, body: body}} ->
        case Poison.decode!(body) do
          %{"data" => %{"available" => true}} ->
            :available
          %{"data" => %{"available" => false}} ->
            :registered
        end
      {:ok, stuff} ->
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
