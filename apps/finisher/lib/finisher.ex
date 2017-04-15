defmodule Finisher do
  @moduledoc """
  Documentation for Finisher.
  """
  alias Web.Repo
  alias Web.Crawl
  alias Web.Domain
  import Ecto.Query

  def start do
    :timer.apply_interval(5000, Finisher, :finish, [])
    :timer.apply_interval(5000, Finisher, :find_unfound_domain_stats, [])
  end

  def finish do
    IO.puts "[Finisher] Finishing all the things"
    # all unfinished crawls created more than 20 seconds ago
    crawls = Repo.all(from c in Crawl, where: is_nil(c.finished_at) and c.began_at < datetime_add(^Ecto.DateTime.utc, -60, "second"))
    Enum.each(crawls, fn(crawl) ->
      queued_actions = Store.ToCrawl.list_length(crawl.id) + Store.Domains.list_length(crawl.id)

      if (queued_actions == 0) do
        crawled_urls = Store.Crawled.get_list(crawl.id) |> length

        time_to_end_at =
          Ecto.DateTime.utc
          |> Ecto.DateTime.to_erl
          |> :calendar.datetime_to_gregorian_seconds
          |> Kernel.-(50)
          |> :calendar.gregorian_seconds_to_datetime
          |> Ecto.DateTime.from_erl

        finish_crawl(crawl.id, time_to_end_at, crawled_urls)
      end
    end)
  end

  def find_unfound_domain_stats do
    IO.puts "[Finisher] Finding unfound domain stats"
    domains = Repo.all(from d in Domain, where: d.status == true and is_nil(d.da))
    domains = domains |> Enum.map(fn(domain) ->
      IO.puts "[Finisher] looking up stats for #{domain.domain}"
      stats = Scraper.Core.lookup_stats(domain.domain) |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end) |> Enum.into(%{})
      changeset = Domain.changeset(domain, stats)
      Repo.update!(changeset)
    end)
  end

  defp finish_crawl(crawl_id, time, crawled_urls \\ 0) do
    crawl = Repo.get!(Crawl, crawl_id)
    changeset = Crawl.changeset(crawl, %{finished_at: time, urls: crawled_urls})
    Repo.update!(changeset)
    Scheduler.remove_crawl(crawl_id)
    Store.DomainsChecked.clear(crawl_id)
    Store.Crawled.clear(crawl_id)
  end
end
