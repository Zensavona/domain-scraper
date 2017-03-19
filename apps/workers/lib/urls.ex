defmodule Workers.Urls do

  alias Web.Repo
  alias Web.Url


  @doc """
  Starts a new bucket.
  """
  def start_link() do
    # run Watcher.watch every 10 seconds forever
    # :timer.apply_interval(:timer.seconds(5), Watcher, :watch, [])
    rtnval = Agent.start_link(fn -> [] end, name: __MODULE__)

    Agent.update(__MODULE__, fn(_) ->
      0..49 |> Enum.to_list |> Enum.map(fn (_) -> {:idle, nil} end)
    end)
    get_list |> Enum.with_index |> Enum.each(fn ({worker, index}) ->
      Task.start(fn () -> worker(index) end)
      # :timer.sleep(100)
    end)

    rtnval
  end

  def worker(id) do
    case Store.ToCrawl.pop do
      :empty ->
        # IO.puts "[#{id}] none found, waiting..."
        update(id, {:idle, nil})
        :timer.sleep(1000)
      {crawl_id, url, retries} when retries > 4 ->
        insert(crawl_id, url)
      {crawl_id, url, retries} ->
        IO.puts "[Urls] found a url to crawl: #{url}"
        case Scraper.Core.url_to_urls_and_domains(url) do
          {:error, url} ->
            Store.ToCrawl.push(crawl_id, url, retries + 1)
          {:ok, urls, domains} ->
            insert(crawl_id, url)
            urls |> Enum.each(&(Task.start(fn -> Store.ToCrawl.push(crawl_id, &1) end)))
            domains |> Enum.each(&(Task.start(fn -> Store.Domains.push(crawl_id, &1) end)))
        end
        update(id, {:busy, url})
        :timer.sleep(100)
    end
    worker(id)
  end

  # crawl = {:id, [urls], [domains]}

  @doc """
  Gets a value from the `bucket` by `key`.
  """
  def get_list do
    Agent.get(__MODULE__, &(&1))
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def get_status(id) do
    # id, status (:idle, :busy), url ({crawl_id, url, retries}) || nil
    worker = {:idle, nil}
    Agent.update(__MODULE__, fn(list) -> [worker | list] end)
  end

  @doc """
  takes an id and a worker to replace (either {:idle, nil} or {:busy, {crawl_id, url, retries}})
  """
  def update(id, worker) do
    new_list = List.replace_at(get_list(), id, worker)
    Agent.update(__MODULE__, fn (_) -> new_list end)
  end

  defp insert(crawl_id, url) do
    case Repo.insert(Url.changeset(%Url{}, %{url: url, crawl_id: crawl_id})) do
      {:ok, _} ->
        IO.puts "[Urls] Inserted #{url}"
      {:error, _} ->
        IO.puts "[Urls] Error inserting #{url}, probably a duplicate"
    end
  end
end
