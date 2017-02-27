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
        IO.puts "#{url} Not found :("
        {:ok, [], []}
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
      {:closed, _} ->
        {:error, "closed on #{url}"}
      :closed ->
        {:error, "closed on #{url}"}
    end
  end

  def work_on_url(id, url) do
    Scraper.Store.Crawled.push(id, url)
    case url_to_urls_and_domains(url) do
      {:ok, urls, domains} ->
        # IO.puts "run/1 found #{length(urls)} urls, #{length(domains)} domains"
        crawled = Scraper.Store.Crawled.get_list(id)
        urls
          |> Enum.reject(fn(url) -> Enum.member?(crawled, url) end)
          |> Enum.each(&(Task.start(fn -> work_on_url(id, &1) end)))
        domains
          |> Enum.each(&(Task.start(fn -> check_domain_and_push_to_store(id, &1) end)))
      {:error, reason} ->
        IO.puts "error: #{reason}"
      :closed ->
        IO.puts "Closed on run/1 with #{url}... wtf"
      :timeout ->
        IO.puts "Timed out on #{url}"
    end
    # IO.puts "#{length(Scraper.Store.Crawled.get_list(seed_url))} urls crawled, #{length(Scraper.Store.Domains.get_list(seed_url))} external domains found"
  end

  # private

  defp check_domain_and_push_to_store(id, domain) do
    parsed = Domainatrex.parse(domain)
    domain = "#{Map.get(parsed, :domain)}.#{Map.get(parsed, :tld)}"
    case Whois.lookup domain do
      {:ok, %Whois.Record{created_at: nil}} ->
        Scraper.Store.Domains.push(id, {domain, true})
        :ok
      {:ok, _} ->
        Scraper.Store.Domains.push(id, {domain, false})
        :ok
      {:error, _} ->
        :error
    end
  end

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
