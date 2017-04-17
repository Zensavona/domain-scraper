defmodule Workers.Url do

  def worker do
    case Scheduler.pop_url do
      :empty ->
        # IO.puts "[Urls] none found, waiting..."
        :timer.sleep(1000)
      {crawl_id, url} ->
        IO.puts "[Urls] found a url to crawl: #{url} (#{crawl_id})"
        case Scraper.Core.url_to_urls_and_domains(url) do
          {:error, url} ->
            Store.Crawled.push(crawl_id, url)
          {:ok, urls, domains} ->
            Store.Crawled.push(crawl_id, url)
            Store.ToCrawl.push(crawl_id, urls)
            domains |> Enum.each(&(Store.Domains.push(crawl_id, &1)))
          other ->
            IO.puts "[Url] Something fucked up... (#{other})"
        end
    end
    worker()
  end
end
