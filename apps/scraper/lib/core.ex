defmodule Scraper.Core do
  alias HTTPoison

  @doc """
    Transform a single URL into a tuple containing two lists: urls and domains contained at that url.
    Examples:
      {:ok, urls, domains}
      {:error, original_url}
  """
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

  @doc """
    Check the status of a domain. This is a rather difficult process so it's split into multiple steps to save DNSimple API calls (limited to 2400/hr)
    1. Just do a GET request to it, if that doesn't return :nxdomain, we know it's registered.
    2. Check Whois, this mostly works but returns some false positive.
    3. If both of those things indicate the domain is available, check the DNSimple API to see if it can be registered.
  """
  def check_domain(domain) do
    if domain_kind_of_at_least_makes_sense?(domain) do
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
    else
      {:error, nil}
    end
  end

  # private

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

  defp check_from_dnsimple(domain) do
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
  defp normalise_urls(urls, base_url) do
    urls
      |> Enum.filter(&domain_kind_of_at_least_makes_sense?/1)
      |> Enum.reject(&String.contains?(&1, "mailto:"))
      |> Enum.map(fn(u) -> if !String.contains?(u, "http"), do: "#{base_url}/#{u}", else: u end)
  end
  defp domain_kind_of_at_least_makes_sense?(domain) do
    if is_bitstring(domain) && String.contains?(domain, ".") do
      true
    else
      false
    end
  end
end
