defmodule Scraper do
  @moduledoc """
  Documentation for Scraper.
  """

  def init(url) do
    Scraper.Store.Crawled.start_link(url)
    Scraper.Store.Domains.start_link(url)
    Scraper.Core.work_on_url(url, url)
  end

  def check_domains do
    domains = Scraper.Store.Domains.get_list
    domains |> Enum.each(&(Task.start(fn -> Scraper.Core.check_domain(&1) end)))
  end
end
