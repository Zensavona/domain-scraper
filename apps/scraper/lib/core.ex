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

    with {:ok, %HTTPoison.Response{status_code: 200, body: body, headers: headers}} <- HTTPoison.get(url, [], hackney: [pool: :first_pool]),
         true <- html_content_type?(headers) do
           Floki.find(body, "a") |> Floki.attribute("href") |> normalise_urls("http://#{domain}") |> links_to_urls_and_domains(domain, url)
         else
           {:ok, %HTTPoison.Response{status_code: 301, headers: headers}} ->
             url = headers |> Enum.into(%{}) |> Map.get("Location")
             {:ok, [url], []}
           {:ok, %HTTPoison.Response{status_code: 302, headers: headers}} ->
             url = headers |> Enum.into(%{}) |> Map.get("Location")
             {:ok, [url], []}
           _ ->
             {:error, url}
         end
  end

  @doc """
    Check the status of a domain. This is a rather difficult process so it's split into multiple steps to save DNSimple API calls (limited to 2400/hr)
  """
  def check_domain(domain) do
    with {:ok, domain} <- domain_kind_of_at_least_makes_sense?(domain),
         {:ok, parsed} <- Domainatrex.parse(domain),
         domain <- "#{Map.get(parsed, :domain)}.#{Map.get(parsed, :tld)}",
         {:error, %HTTPoison.Error{id: nil, reason: :nxdomain}} <- HTTPoison.get(domain, [], hackney: [pool: :first_pool]),
         {:ok, %Whois.Record{created_at: nil}} <- Whois.lookup(domain),
         :available <- check_from_dnsimple(domain) do
           {:available, lookup_stats(domain)}
         else
           {:ok, _http} -> {:registered, nil}
           _ -> {:error, nil}
         end
  end

  # private

  def links_to_urls_and_domains(links, domain, url) do
    urls = links
      |> Enum.reject(fn(l) -> domain_from_url(l) !== domain end)
      |> Enum.reject(fn(l) -> l == url end)

    domains = links |> Enum.reject(fn(l) -> domain_from_url(l) == domain end) |> Enum.map(&domain_from_url(&1))

    {:ok, urls, domains}
  end

  def html_content_type?(headers) do
    headers = headers |> Map.new
    if Map.get(headers, "Content-Type") && String.contains?(Map.get(headers, "Content-Type"), "html") do
      true
    else
      false
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

  def domain_from_url(url) do
    host = URI.parse(url).host
    {:ok, bits} = Domainatrex.parse(host)
    "#{bits.domain}.#{bits.tld}"
  end

  def normalise_urls(urls, base_url) do
    urls
      |> Enum.filter(&domain_kind_of_at_least_makes_sense?/1)
      |> Enum.reject(&String.contains?(&1, "mailto:"))
      |> Enum.map(fn(u) -> if !String.contains?(u, "http"), do: "#{base_url}/#{u}", else: u end)
  end

  def domain_kind_of_at_least_makes_sense?(domain) do
    if is_bitstring(domain) && String.contains?(domain, ".") do
      {:ok, domain}
    else
      {:error, domain}
    end
  end
end
