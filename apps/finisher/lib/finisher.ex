defmodule Finisher do
  @moduledoc """
  Documentation for Finisher.
  """
  alias Web.Repo
  alias Web.Crawl
  alias Web.Url
  import Ecto.Query

  def start do
    :timer.apply_interval(5000, Finisher, :finish, [])
  end

  def finish do
    IO.puts "[Finisher] Finishing all the things"
    # all unfinished crawls created more than 20 seconds ago
    crawls = Repo.all(from c in Crawl, where: is_nil(c.finished_at) and c.began_at < datetime_add(^Ecto.DateTime.utc, -30, "second"))
    Enum.each(crawls, fn(crawl) ->
      queued_actions = Store.ToCrawl.get_list(crawl.id) ++ Store.Domains.get_list(crawl.id)
      if (length(queued_actions) == 0) do
        case Repo.all(from u in Url, where: u.crawl_id == ^crawl.id, order_by: [asc: u.inserted_at]) do
          # none exist, finish it
          [] ->
            finish_crawl(crawl.id, Ecto.DateTime.utc)
          urls ->
            ecto_30_sec_ago =
              Ecto.DateTime.utc
              |> Ecto.DateTime.to_erl
              |> :calendar.datetime_to_gregorian_seconds
              |> Kernel.-(30)
              |> :calendar.gregorian_seconds_to_datetime
              |> Ecto.DateTime.from_erl
            last_date_time = List.last(urls).inserted_at |> Ecto.DateTime.cast!

            if (Ecto.DateTime.compare(last_date_time, ecto_30_sec_ago) == :lt) do
              finish_crawl(crawl.id, last_date_time)
            end
        end
      end
    end)
  end

  defp finish_crawl(crawl_id, time) do
    crawl = Repo.get!(Crawl, crawl_id)
    changeset = Crawl.changeset(crawl, %{finished_at: time})
    Repo.update!(changeset)
  end
end
