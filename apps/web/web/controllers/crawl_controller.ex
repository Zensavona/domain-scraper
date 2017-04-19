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
    crawls = current_user |> Crawl.all_for_user_without_crawl_set_members |> Repo.all

    crawl_sets = Repo.all(from c in CrawlSet, where: c.user_id == ^current_user.id, preload: :crawls) |> Enum.map(fn(crawl_set) ->
                                                                                                          queued = Enum.reduce(crawl_set.crawls, false, fn(c, acc) ->
                                                                                                            if (acc == false && c.is_queued == true) do
                                                                                                              true
                                                                                                            else
                                                                                                              acc
                                                                                                            end
                                                                                                          end)
                                                                                                          Map.put(crawl_set, :is_queued, queued)
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

    render(conn, "index.html", crawls: crawls)
  end

  def new(conn, _params, current_user) do
    changeset = Crawl.changeset(%Crawl{})
    render(conn, "new.html", changeset: changeset)
  end

  # one url
  def create(conn, %{"crawl" => %{"seed" => seed, "phrase" => "", "seed_list" => ""}}, current_user) do
    crawl_params = %{"seed" => seed, "is_queued" => true} # Map.put(crawl_params, "is_queued", true)

    changeset =
      current_user
      |> build_assoc(:crawls)
      |> Crawl.changeset(Map.put(crawl_params, "began_at", Ecto.DateTime.utc))

    case Repo.insert(changeset) do
      {:ok, crawl} ->
        # Scheduler.add_crawl(crawl.id)
        # Scraper.start_new_crawl(crawl.id, crawl.seed)
        conn
        |> put_flash(:info, "Crawl created successfully.")
        |> redirect(to: crawl_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  # bulk urls
  def create(conn, %{"crawl" => %{"seed" => "", "phrase" => "", "seed_list" => seed_list}}, current_user) do
    crawls = seed_list
      |> String.split("\n")
      |> Enum.map(&(String.trim_trailing(&1, "\r")))
      |> Enum.map(fn(s) -> Crawl.changeset(%Crawl{began_at: Ecto.DateTime.utc, is_queued: true, seed: s, user_id: current_user.id}) end)

    Enum.each(crawls, &Repo.insert!/1)

    conn
    |> put_flash(:info, "Crawl Set created successfully.")
    |> redirect(to: crawl_path(conn, :index))
  end

  # phrase
  def create(conn, %{"crawl" => %{"phrase" => phrase, "seed" => "", "seed_list" => ""}}, current_user) do
    crawl_params = %{"phrase" => phrase, "is_queued" => true} # Map.put(crawl_params, "is_queued", true)

    seeds = phrase |> Lmgtfy.search |> Enum.uniq_by(fn(i) -> URI.parse(i).host end) |> Enum.take(10)
    crawls = Enum.map(seeds, fn(s) -> %{began_at: Ecto.DateTime.utc, seed: s, is_queued: true} end)

    # changeset = CrawlSet.changeset(%CrawlSet{began_at: Ecto.DateTime.utc}, %{phrase: phrase, crawls: crawls})
    crawl_set_params = %{began_at: Ecto.DateTime.utc, phrase: phrase, crawls: crawls}

    changeset =
      current_user
      |> build_assoc(:crawl_sets)
      |> CrawlSet.changeset(crawl_set_params)

    case Repo.insert(changeset) do
      {:ok, crawl_set} ->
        conn
        |> put_flash(:info, "Crawl Set created successfully.")
        |> redirect(to: crawl_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
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

    queued = Enum.reduce(crawl.crawls, false, fn(c, acc) ->
      if (acc == false && c.is_queued == true) do
        true
      else
        acc
      end
    end)
    crawl = Map.put(crawl, :is_queued, queued)

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
