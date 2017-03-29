defmodule Web.CrawlController do
  use Web.Web, :controller
  alias Web.Crawl
  alias Web.Domain

  def index(conn, _params) do
    crawls = Repo.all(Crawl) |> Repo.preload(:urls)
    crawls = Enum.map(crawls, fn(c) ->
      c = Map.put(c, :began_at, Timex.from_now(Timex.to_datetime(Ecto.DateTime.to_erl(c.began_at))))
      if c.finished_at do
        Map.put(c, :finished_at, Timex.from_now(Timex.to_datetime(Ecto.DateTime.to_erl(c.finished_at))))
      else
        c
      end
    end)

    stats = %{
      urls: Store.ToCrawl.list_length,
      domains: Store.Domains.list_length
    }

    render(conn, "index.html", crawls: crawls, stats: stats)
  end

  def new(conn, _params) do
    changeset = Crawl.changeset(%Crawl{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"crawl" => crawl_params}) do
    changeset = Crawl.changeset(%Crawl{began_at: Ecto.DateTime.utc}, crawl_params)

    case Repo.insert(changeset) do
      {:ok, crawl} ->
        Scraper.start_new_crawl(crawl.id, crawl.seed)
        conn
        |> put_flash(:info, "Crawl created successfully.")
        |> redirect(to: crawl_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    crawl = Repo.get!(Crawl, id) |> Repo.preload(domains: from(d in Domain, order_by: [desc: d.status])) |> Repo.preload([:urls])

    crawl = if crawl.finished_at do
      began_at = Timex.to_datetime(Ecto.DateTime.to_erl(crawl.began_at))
      finished_at = Timex.to_datetime(Ecto.DateTime.to_erl(crawl.finished_at))
      time_taken_secs = Timex.diff(finished_at, began_at, :seconds)

      crawl = if (time_taken_secs < 120) do
        Map.put(crawl, :time_taken_sec, time_taken_secs)
      else
        Map.put(crawl, :time_taken_min, Timex.diff(finished_at, began_at, :minutes))
      end

      Map.put(crawl, :urls, length(crawl.urls))
    else
      crawl = Map.put(crawl, :urls, Store.Crawled.list_length(crawl.id))
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
