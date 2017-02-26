defmodule Web.CrawlController do
  use Web.Web, :controller
  alias Web.Crawl

  def index(conn, _params) do
    crawls = Repo.all(Crawl)
    render(conn, "index.html", crawls: crawls)
  end

  def new(conn, _params) do
    changeset = Crawl.changeset(%Crawl{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"crawl" => crawl_params}) do
    changeset = Crawl.changeset(%Crawl{began_at: Ecto.DateTime.utc}, crawl_params)

    case Repo.insert(changeset) do
      {:ok, crawl} ->
        Scraper.init(crawl.id, crawl.seed)
        conn
        |> put_flash(:info, "Crawl created successfully.")
        |> redirect(to: crawl_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    crawl = Repo.get!(Crawl, id) |> Repo.preload(:domains)
    
    # if the crawl is in progress, get the in mem data
    case crawl.finished_at do
      nil ->
        crawl = Map.put(crawl, :urls, length(Scraper.Store.Crawled.get_list(crawl.id)))
        crawl = Map.put(crawl, :unchecked_domains, Scraper.Store.Domains.get_list(crawl.id))
      _ ->
        crawl = Map.put(crawl, :unchecked_domains, [])
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
