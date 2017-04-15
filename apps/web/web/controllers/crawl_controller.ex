defmodule Web.CrawlController do
  use Web.Web, :controller
  alias Web.Crawl
  alias Web.CrawlSet
  alias Web.Domain

  def action(conn, _) do
    apply(__MODULE__, action_name(conn),
          [conn, conn.params, conn.assigns.current_user])
  end

  def index(conn, _params, current_user) do
    crawls = current_user |> Crawl.all_for_user_without_crawl_set_members |> Repo.all |> Repo.preload(:domains)

    crawl_sets = Repo.all(from c in CrawlSet, where: c.user_id == ^current_user.id, preload: [{:crawls, :domains}]) |> Enum.map(fn(crawl_set) ->
      domains = Enum.reduce(crawl_set.crawls, 0, fn(c, acc) -> acc + length(Enum.filter(c.domains, &(&1.status == true))) end)
      crawl_set |> Map.put(:domains, domains) |> Map.put(:seed, crawl_set.phrase)
    end)

    crawls = crawls ++ crawl_sets

    crawls = Enum.map(crawls, fn(c) ->
      c = Map.put(c, :began_at, Timex.from_now(Timex.to_datetime(Ecto.DateTime.to_erl(c.began_at))))
      avail_domains = Enum.filter(c.domains, &(&1.status == true))
      c = Map.put(c, :domains, length(avail_domains))
      if c.finished_at do
        Map.put(c, :finished_at, Timex.from_now(Timex.to_datetime(Ecto.DateTime.to_erl(c.finished_at))))
      else
        c
      end
    end)

    render(conn, "index.html", crawls: crawls)
  end

  def new(conn, _params, current_user) do
    changeset = Crawl.changeset(%Crawl{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"crawl" => crawl_params}, current_user) do
    case Map.get(crawl_params, "phrase") do
      "" ->
        # changeset = Crawl.changeset(%Crawl{began_at: Ecto.DateTime.utc}, crawl_params)
        changeset =
          current_user
          |> build_assoc(:crawls)
          |> Crawl.changeset(Map.put(crawl_params, "began_at", Ecto.DateTime.utc))

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

        # changeset = CrawlSet.changeset(%CrawlSet{began_at: Ecto.DateTime.utc}, %{phrase: phrase, crawls: crawls})
        crawl_set_params = %{began_at: Ecto.DateTime.utc, phrase: phrase, crawls: crawls}

        changeset =
          current_user
          |> build_assoc(:crawl_sets)
          |> CrawlSet.changeset(crawl_set_params)

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

  def show(conn, %{"id" => id}, current_user) do
    # crawl = Repo.get!(Crawl, id) |> Repo.preload(domains: from(d in Domain, order_by: [desc: d.status]))
    crawl = current_user |> Crawl.by_id_for_user(id) |> Repo.one |> Repo.preload(domains: from(d in Domain, order_by: [desc: d.status]))

    case crawl do
      nil ->
        conn
          |> put_status(:not_found)
          |> render(Web.ErrorView, "404.html")
      crawl ->
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
  end

  def show_crawl_set(conn, %{"id" => id}, current_user) do
    # crawl = Repo.get!(Crawl, id) |> Repo.preload(domains: from(d in Domain, order_by: [desc: d.status]))
    crawl = current_user |> CrawlSet.by_id_for_user(id) |> Repo.one # |> Repo.preload(domains: from(d in Domain, order_by: [desc: d.status]))
    crawl = Map.put(crawl, :seed, crawl.phrase)

    domains = Enum.map(crawl.crawls, fn(c) -> c.domains end) |> List.flatten
    urls = Enum.reduce(crawl.crawls, 0, fn(c, acc) -> acc + if is_nil(c.urls), do: 0, else: c.urls end)
    crawl = Map.put(crawl, :domains, domains)
    crawl = Map.put(crawl, :urls, urls)
    crawl = Map.put(crawl, :seeds, Enum.map(crawl.crawls, &(&1.seed)))

    case crawl do
      nil ->
        conn
          |> put_status(:not_found)
          |> render(Web.ErrorView, "404.html")
      crawl ->
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
                    |> Map.put(:urls, Enum.reduce(crawl.crawls, 0, fn(c, acc) -> acc + Store.Crawled.list_length(c.id) end))
                    |> Map.put(:urls_queued, Enum.reduce(crawl.crawls, 0, fn(c, acc) -> acc + Store.ToCrawl.list_length(c.id) end)) #, Store.ToCrawl.list_length(crawl.id))
                    |> Map.put(:domains_queued, Enum.reduce(crawl.crawls, 0, fn(c, acc) -> acc + Store.Domains.list_length(c.id) end)) #, Store.Domains.list_length(crawl.id))
        end

        render(conn, "show.html", crawl: crawl)
    end
  end

  def edit(conn, %{"id" => id}, current_user) do
    crawl = Repo.get!(Crawl, id)
    changeset = Crawl.changeset(crawl)
    render(conn, "edit.html", crawl: crawl, changeset: changeset)
  end

  def update(conn, %{"id" => id, "crawl" => crawl_params}, current_user) do
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

  def delete(conn, %{"id" => id}, current_user) do
    crawl = Repo.get!(Crawl, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(crawl)

    conn
    |> put_flash(:info, "Crawl deleted successfully.")
    |> redirect(to: crawl_path(conn, :index))
  end
end
