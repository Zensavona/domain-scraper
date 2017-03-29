defmodule Workers.Url do

  alias Web.Repo
  alias Web.Url


  def worker do
    case Store.ToCrawl.pop do
      :empty ->
        # IO.puts "[Urls] none found, waiting..."
        :timer.sleep(1000)
      {crawl_id, url} ->
        IO.puts "[Urls] found a url to crawl: #{url}"
        case Scraper.Core.url_to_urls_and_domains(url) do
          {:error, url} ->
            Store.Crawled.push(crawl_id, url)
          {:ok, urls, domains} ->
            Store.Crawled.push(crawl_id, url)
            urls |> Enum.each(&(Store.ToCrawl.push(crawl_id, &1)))
            domains |> Enum.each(&(Store.Domains.push(crawl_id, &1)))
          other ->
            IO.puts "[Url] Something fucked up..."
            IO.inspect other
        end
    end
    worker()
  end

  def insert(crawl_id, url) do
    case Repo.insert(Url.changeset(%Url{}, %{url: url, crawl_id: crawl_id})) do
      {:ok, _} ->
        IO.puts "[Urls] Inserted #{url}"
      {:error, _} ->
        IO.puts "[Urls] Error inserting #{url}, probably a duplicate"
    end
  end
end
