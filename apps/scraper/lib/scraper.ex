defmodule Scraper do
  @moduledoc """
  Documentation for Scraper.
  """

  def start_new_crawl(crawl_id, url) do
    Store.ToCrawl.push(crawl_id, url)
  end
end
