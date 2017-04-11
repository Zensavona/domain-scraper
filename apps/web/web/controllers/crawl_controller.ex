defmodule Web.CrawlController do
  use Web.Web, :controller
  alias Web.Crawl
  alias Web.CrawlSet
  alias Web.Domain

  def index(conn, _params) do
    crawls = Repo.all(from c in Crawl, where: is_nil(c.crawl_set_id))
    crawl_sets = Repo.all(CrawlSet) |> Repo.preload(:crawls) |> Enum.map(fn(crawl_set) ->
      urls = Enum.reduce(crawl_set.crawls, 0, fn(c, acc) -> acc + if is_nil(c.urls), do: 0, else: c.urls end)
      crawl_set |> Map.put(:urls, urls) |> Map.put(:seed, crawl_set.phrase)
    end)
    crawls = crawls ++ crawl_sets
    crawls = Enum.map(crawls, fn(c) ->
      c = Map.put(c, :began_at, Timex.from_now(Timex.to_datetime(Ecto.DateTime.to_erl(c.began_at))))
      if c.finished_at do
        Map.put(c, :finished_at, Timex.from_now(Timex.to_datetime(Ecto.DateTime.to_erl(c.finished_at))))
      else
        c
      end
    end)

    stats = %{
      urls: 0,
      domains: 0
    }

    render(conn, "index.html", crawls: crawls, stats: stats)
  end

  def new(conn, _params) do
    changeset = Crawl.changeset(%Crawl{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"crawl" => crawl_params}) do
    case Map.get(crawl_params, "phrase") do
      "" ->
        changeset = Crawl.changeset(%Crawl{began_at: Ecto.DateTime.utc}, crawl_params)
        case Repo.insert(changeset) do
          {:ok, crawl} ->
            Scheduler.add_crawl(crawl.id)
            Scraper.start_new_crawl(crawl.id, crawl.seed)
            conn
            |> put_flash(:info, "Crawl created successfully.")
            |> redirect(to: crawl_path(conn, :index))
          {:error, changeset} ->
            render(conn, "new.html", changeset: changeset)
        end
      phrase ->
        seeds = phrase |> Lmgtfy.search |> Enum.uniq_by(fn(i) -> URI.parse(i).host end) |> Enum.take(10)
        crawls = Enum.map(seeds, fn(s) -> %{began_at: Ecto.DateTime.utc, seed: s} end)
        changeset = CrawlSet.changeset(%CrawlSet{began_at: Ecto.DateTime.utc}, %{phrase: phrase, crawls: crawls})
        case Repo.insert(changeset) do
          {:ok, crawl_set} ->
            crawl_set = Repo.preload(crawl_set, :crawls)
            Enum.each(crawl_set.crawls, fn(c) ->
              Scheduler.add_crawl(c.id)
              Scraper.start_new_crawl(c.id, c.seed)
            end)

            conn
            |> put_flash(:info, "Crawl Set created successfully.")
            |> redirect(to: crawl_path(conn, :index))
          {:error, changeset} ->
            render(conn, "new.html", changeset: changeset)
        end
    end
  end

  def show(conn, %{"id" => id}) do
    crawl = Repo.get!(Crawl, id) |> Repo.preload(domains: from(d in Domain, order_by: [desc: d.status]))

    crawl = if crawl.finished_at do
      began_at = Timex.to_datetime(Ecto.DateTime.to_erl(crawl.began_at))
      finished_at = Timex.to_datetime(Ecto.DateTime.to_erl(crawl.finished_at))
      time_taken_secs = Timex.diff(finished_at, began_at, :seconds)

      if (time_taken_secs < 120) do
        Map.put(crawl, :time_taken_sec, time_taken_secs)
      else
        Map.put(crawl, :time_taken_min, Timex.diff(finished_at, began_at, :minutes))
      end
    else
      crawl = crawl
                |> Map.put(:urls, Store.Crawled.list_length(crawl.id))
                |> Map.put(:urls_queued, Store.ToCrawl.list_length(crawl.id))
                |> Map.put(:domains_queued, Store.Domains.list_length(crawl.id))
    end


    render(conn, "show.html", crawl: crawl)
  end

  def edit(conn, %{"id" => id}) do
    crawl = Repo.get!(Crawl, id)
    changeset = Crawl.changeset(crawl)
    render(conn, "edit.html", crawl: crawl, changeset: changeset)
  end

  def update(conn, %{"id" => id, "crawl" => crawl_params}) do
    crawl = Repo.get!(Crawl, id)
    changeset = Crawl.changeset(crawl, crawl_params)

    case Repo.update(changeset) do
      {:ok, crawl} ->
        conn
        |> put_flash(:info, "Crawl updated successfully.")
        |> redirect(to: crawl_path(conn, :show, crawl))
      {:error, changeset} ->
        render(conn, "edit.html", crawl: crawl, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    crawl = Repo.get!(Crawl, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(crawl)

    conn
    |> put_flash(:info, "Crawl deleted successfully.")
    |> redirect(to: crawl_path(conn, :index))
  end
end
