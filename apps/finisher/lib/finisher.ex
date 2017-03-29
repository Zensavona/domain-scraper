defmodule Finisher do
  @moduledoc """
  Documentation for Finisher.
  """
  alias Web.Repo
  alias Web.Crawl
  import Ecto.Query

  def start do
    :timer.apply_interval(5000, Finisher, :finish, [])
  end

  def finish do
    IO.puts "[Finisher] Finishing all the things"
    # all unfinished crawls created more than 20 seconds ago
    crawls = Repo.all(from c in Crawl, where: is_nil(c.finished_at) and c.began_at < datetime_add(^Ecto.DateTime.utc, -30, "second"))
    Enum.each(crawls, fn(crawl) ->
      queued_actions = Store.ToCrawl.list_length(crawl.id) + Store.Domains.list_length(crawl.id)

      if (queued_actions == 0) do
        crawled_urls = Store.Crawled.get_list(crawl.id)

        time_to_end_at =
          Ecto.DateTime.utc
          |> Ecto.DateTime.to_erl
          |> :calendar.datetime_to_gregorian_seconds
          |> Kernel.-(20)
          |> :calendar.gregorian_seconds_to_datetime
          |> Ecto.DateTime.from_erl

        crawled_urls |> Enum.each(fn(i) -> Workers.Url.insert(crawl.id, i) end)

        finish_crawl(crawl.id, time_to_end_at)
      end
    end)
  end

  defp finish_crawl(crawl_id, time) do
    crawl = Repo.get!(Crawl, crawl_id)
    changeset = Crawl.changeset(crawl, %{finished_at: time})
    Repo.update!(changeset)
  end
end
