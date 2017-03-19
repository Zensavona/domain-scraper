defmodule Scraper do
  @moduledoc """
  Documentation for Scraper.
  """

  def init() do
    # Scraper.Store.Crawled.start_link()
    # Scraper.Store.ToCrawl.start_link()
    # Scraper.Store.Domains.start_link()
  end

  def start_new_crawl(crawl_id, url) do
    Store.ToCrawl.push(crawl_id, url)
  end
end
