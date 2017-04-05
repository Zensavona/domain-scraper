defmodule Workers.Url do

  require DogStatsd

  def worker do
    DogStatsd.time(:dogstatsd, "worker.url.time") do
      case Store.ToCrawl.pop do
        :empty ->
          # IO.puts "[Urls] none found, waiting..."
          :timer.sleep(1000)
        {crawl_id, url} ->
          IO.puts "[Urls] found a url to crawl: #{url}"
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
              # urls |> Enum.each(&(Store.ToCrawl.push(crawl_id, &1)))
              
              domains |> Enum.each(&(Store.Domains.push(crawl_id, &1)))
            other ->
              DogStatsd.increment(:dogstatsd, "worker.url.checked")
              DogStatsd.increment(:dogstatsd, "worker.url.unknown")
              IO.puts "[Url] Something fucked up..."
              IO.inspect other
          end
      end
    end
    worker()
  end
end
