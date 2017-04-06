defmodule Workers.Url do

  require DogStatsd

  def worker do
    DogStatsd.time(:dogstatsd, "worker.url.time") do
      case Scheduler.pop_url do
        :empty ->
          # IO.puts "[Urls] none found, waiting..."
          :timer.sleep(1000)
        {crawl_id, url} ->
          IO.puts "[Urls] found a url to crawl: #{url} (#{crawl_id})"
          case Scraper.Core.url_to_urls_and_domains(url) do
            {:error, url} ->
              Store.Crawled.push(crawl_id, url)
              DogStatsd.increment(:dogstatsd, "worker.url.checked")
              DogStatsd.increment(:dogstatsd, "worker.url.error")
            {:ok, urls, domains} ->
              DogStatsd.increment(:dogstatsd, "worker.url.checked")
              DogStatsd.increment(:dogstatsd, "worker.url.normal")

              Store.Crawled.push(crawl_id, url)
              Store.ToCrawl.push(crawl_id, urls)
              domains |> Enum.each(&(Store.Domains.push(crawl_id, &1)))
            other ->
              DogStatsd.increment(:dogstatsd, "worker.url.checked")
              DogStatsd.increment(:dogstatsd, "worker.url.unknown")
              IO.puts "[Url] Something fucked up... (#{other})"
          end
      end
    end
    worker()
  end
end
