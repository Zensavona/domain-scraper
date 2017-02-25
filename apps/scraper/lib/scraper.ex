defmodule Scraper do
  @moduledoc """
  Documentation for Scraper.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Scraper.hello
      :world

  """

  def init(url) do
    IO.puts "run/1 with #{url}"

    Scraper.Store.ToCrawl.start_link
    Scraper.Store.Crawled.start_link
    Scraper.Store.DomainsToCheck.start_link

    Scraper.Core.work_on_url(url)
  end

  def check_domains do
    domains = Scraper.Store.DomainsToCheck.get_list
    # domains |> Enum.each(&Scraper.Core.check_domain/1)
    domains |> Enum.each(&(Task.start(fn -> Scraper.Core.check_domain(&1) end)))
  end
end
