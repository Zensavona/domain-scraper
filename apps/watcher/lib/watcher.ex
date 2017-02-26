defmodule Watcher do
  @moduledoc """
  Documentation for Watcher.
  """
  @mins_inactive 1

  alias Web.Repo
  alias Web.Crawl
  alias Web.Domain
  import Ecto.Query

  def init do
    IO.puts "watcher init"
    Watcher.Store.start_link
    # :timer.apply_interval(:timer.seconds(10), Watcher, :watch, [])
  end

  def watch do
    IO.puts "Running Watch"

    # if the last two values for both urls and domains are the same, insert an end time and end the crawl
    Enum.each(Watcher.Store.get_list, fn(c) ->
      case c do
        # this has run more than twice
        {id, urls, domains} when length(urls) >= 2 and length(domains) >= 2 ->
          # the last two results were the same
          if Enum.at(urls, 0) == Enum.at(urls, 1) && Enum.at(domains, 0) == Enum.at(domains, 1) do
            # update the crawl with finished at
            id = id |> to_string |> String.to_integer
            crawl = Repo.get!(Crawl, id)
            # insert the domains
            domains = Scraper.Store.Domains.get_list(to_string(id))
            Enum.each(domains, &(Repo.insert!(Domain.changeset(%Domain{}, %{domain: &1, status: false, crawl_id: crawl.id}))))

            # update the crawl with a finished datetime
            crawl |> Crawl.changeset(%{finished_at: Ecto.DateTime.utc, urls: Enum.at(urls, 0)}) |> Repo.update!

            # remove it from the Watcher Store
            Watcher.Store.remove(:"#{id}")
          end
        _ ->
        IO.puts "nothing up update"
      end
    end)

    crawls = Watcher.Store.get_list

    # update the crawls in the store with new values
    update_crawls crawls

    # get crawls who have no end datetime
    query = from c in Crawl, where: is_nil c.finished_at
    crawls_from_db = Repo.all(query)

    # make a list of their IDs
    crawls_in_store_ids = Enum.map(crawls, fn(c) ->
      {id, _, _} = c
      id |> to_string |> String.to_integer
    end)

    in_progress_crawls_not_in_the_store = Enum.reject(crawls_from_db, fn(c) -> Enum.member?(crawls_in_store_ids, c.id) end)

    # add them to the store with initial values
    # crawl = {:id, [urls], [domains]}
    Enum.each(in_progress_crawls_not_in_the_store, fn(c) ->
      id_s = to_string c.id
      Watcher.Store.push({ :"#{c.id}", [length(Scraper.Store.Crawled.get_list(id_s))], [length(Scraper.Store.Domains.get_list(id_s))] })
    end)
  end

  def update_crawls(crawls) do
    Enum.each(crawls, fn(c) ->
      {id_a, old_urls, old_domains} = c
      id_s = to_string(id_a)

      urls = Scraper.Store.Crawled.get_list(id_s)
      domains = Scraper.Store.Domains.get_list(id_s)

      Watcher.Store.update(id_a, {id_a, [length(urls) | old_urls], [length(domains) | old_domains]})
    end)
  end
end
