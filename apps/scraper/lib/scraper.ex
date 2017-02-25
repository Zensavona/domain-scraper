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

  def run do
    IO.puts "#{length(Scraper.Store.Crawled.get_list)} urls crawled, #{length(Scraper.Store.ToCrawl.get_list)} left to crawl"
    case Scraper.Store.ToCrawl.pop do
      {:ok, url} ->
        IO.puts "run/1 popped #{url}"
        Scraper.Store.Crawled.push(url)
        Task.start(fn -> run(url) end)
        # run(url)
      {:none} ->
        IO.puts "nothing to crawl"
    end
  end

  def run(url) do
    IO.puts "run/1 with #{url}"

    Scraper.Store.ToCrawl.start_link
    Scraper.Store.Crawled.start_link
    Scraper.Store.DomainsToCheck.start_link

    IO.puts "#{length(Scraper.Store.Crawled.get_list)} urls crawled, #{length(Scraper.Store.ToCrawl.get_list)} left to crawl"

    # {:ok, urls, domains} = Scraper.Core.url_to_urls_and_domains(url)

    case Scraper.Core.url_to_urls_and_domains(url) do
      {:ok, urls, domains} ->
        IO.puts "run/1 found #{length(urls)} urls, #{length(domains)} domains"
        crawled = Scraper.Store.Crawled.get_list
        urls
          |> Enum.reject(fn(url) -> Enum.member?(crawled, url) end)
          |> Enum.each(fn(url) -> Scraper.Store.ToCrawl.push(url) end)
        domains |> Enum.each(fn(d) -> Scraper.Store.DomainsToCheck.push(d) end)
        run()
      {:error, reason} ->
        IO.puts "error: #{reason}"
        run()
      :closed ->
        IO.puts "Closed on run/1 with #{url}... wtf"
        run()
    end

  end

  def check_domains do
    domains = Scraper.Store.DomainsToCheck.get_list
    # domains |> Enum.each(&Scraper.Core.check_domain/1)
    domains |> Enum.each(&(Task.start(fn -> Scraper.Core.check_domain(&1) end)))
  end

#   def init(url) do
#     IO.puts "init/1 with #{url}"
#     Scraper.Store.Crawled.start_link
#     run_async(url)
#   end
#
#   def run_async(url) do
#     IO.puts "run_async/1 with #{url}"
#
#     {:ok, urls, _domains} = Scraper.Core.url_to_urls_and_domains(url)
#
#     IO.puts "found #{length(urls)} urls"
#
#     Scraper.Store.Crawled.push(url)
#
#     crawled = Scraper.Store.Crawled.get_list
#
#     urls
#       |> Enum.reject(fn(url) -> Enum.member?(crawled, url) end)
#       |> Enum.each(&(Task.start(fn -> run_async(&1) end)))
#   end

end
