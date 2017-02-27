defmodule Scraper do
  @moduledoc """
  Documentation for Scraper.
  """

  def init(id, url) do
    Scraper.Store.Crawled.start_link(id)
    Scraper.Store.Domains.start_link(id)
    Scraper.Core.work_on_url(id, url)
  end
end
