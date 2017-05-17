defmodule Workers.Url do

  require DogStatsd
  require Logger

  def worker do
    case Scheduler.pop_url do
      :empty ->
        :timer.sleep(1000)
      {crawl_id, url} ->
        DogStatsd.time(:dogstatsd, "worker.url.time") do
          Logger.info "[Urls] found a url to crawl: #{url} (#{crawl_id})"
          case Scraper.Core.url_to_urls_and_domains(url) do
            {:error, url} ->
              Store.Crawled.push(crawl_id, url)
              DogStatsd.increment(:dogstatsd, "worker.url.checked")
              DogStatsd.increment(:dogstatsd, "worker.url.error")
            {:ok, urls, domains} ->
              Store.Crawled.push(crawl_id, url)
              Store.ToCrawl.push(crawl_id, urls)
              domains |> Enum.each(&(Store.Domains.push(crawl_id, &1)))
              DogStatsd.increment(:dogstatsd, "worker.url.checked")
              DogStatsd.increment(:dogstatsd, "worker.url.normal")
            other ->
              Logger.info "[Url] Something fucked up... (#{other})"
              DogStatsd.increment(:dogstatsd, "worker.url.checked")
              DogStatsd.increment(:dogstatsd, "worker.url.unknown")
          end
        end
    end
    worker()
  end
end
