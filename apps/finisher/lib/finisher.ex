defmodule Finisher do
  @moduledoc """
  Documentation for Finisher.
  """
  alias Web.Repo
  alias Web.Crawl
  alias Web.Domain
  alias Web.User
  import Ecto.Query
  @per_user_concurrency_limit

  def start do
    :timer.apply_interval(5000, Finisher, :finish, [])
    :timer.apply_interval(5000, Finisher, :find_unfound_domain_stats, [])
    :timer.apply_interval(5000, Finisher, :handle_crawl_queue, [])
  end

  def finish do
    IO.puts "[Finisher] Finishing all the things"
    # all unfinished crawls created more than 20 seconds ago
    crawls = Repo.all(from c in Crawl, where: is_nil(c.finished_at) and c.is_queued == false and c.began_at < datetime_add(^Ecto.DateTime.utc, -60, "second"))
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
    domains = Repo.all(from d in Domain, where: d.status == true and is_nil(d.cf))
    domains = domains |> Enum.map(fn(domain) ->
      IO.puts "[Finisher] looking up stats for #{domain.domain}"
      stats = Scraper.Core.lookup_stats(domain.domain) |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end) |> Enum.into(%{})
      changeset = Domain.changeset(domain, stats)
      Repo.update!(changeset)
    end)
  end

  def handle_crawl_queue do
    # find users who have less than 10 crawls queued and not finished, add those to the scheduler
    users = Repo.all(from u in User)
    Enum.each(users, fn(user) ->
      crawls = Repo.all(from c in Crawl, where: is_nil(c.finished_at) and c.user_id == ^user.id)
      case crawls |> Enum.filter(&(&1.is_queued == false)) |> length do
        len when len < 10 ->
          # start new ones up
          crawls
            |> Enum.filter(&(&1.is_queued == true))
            |> Enum.take(10 - len)
            |> Enum.each(fn(c) ->
              c |> Crawl.changeset(%{is_queued: false}) |> Repo.update!
              Scraper.start_new_crawl(c.id, c.seed)
              Scheduler.add_crawl(c.id)
              IO.puts "[Queue] Dequeued a crawl for user #{user.id}"
            end)
        _ ->
          :nothing
      end
    end)
  end

  defp finish_crawl(crawl_id, time, crawled_urls \\ 0) do
    crawl = Repo.get!(Crawl, crawl_id)
    changeset = Crawl.changeset(crawl, %{finished_at: time, urls: crawled_urls, is_queued: false})
    Repo.update!(changeset)
    Scheduler.remove_crawl(crawl_id)
    Store.DomainsChecked.clear(crawl_id)
    Store.Crawled.clear(crawl_id)
  end
end
