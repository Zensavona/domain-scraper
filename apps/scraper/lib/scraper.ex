defmodule Scraper do
  @moduledoc """
  Documentation for Scraper.
  """

  def init(id, url) do
    Scraper.Store.Crawled.start_link(id)
    Scraper.Store.Domains.start_link(id)
    Scraper.Core.work_on_url(id, url)
  end

  def check_domains(id) do
    domains = Scraper.Store.Domains.get_list(id)
    domains |> Enum.each(&(Task.start(fn -> Scraper.Core.check_domain(&1) end)))
  end
end
