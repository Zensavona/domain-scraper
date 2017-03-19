defmodule Workers.Domains do

  alias Web.Repo
  alias Web.Domain

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
    get_list() |> Enum.with_index |> Enum.each(fn ({worker, index}) ->
      Task.start(fn () -> worker(index) end)
    end)

    rtnval
  end

  def worker(id) do
    case Store.Domains.pop do
      :empty ->
        # IO.puts "[#{id}] none found, waiting..."
        Workers.Domains.update(id, {:idle, nil})
        :timer.sleep(1000)
      {crawl_id, domain, retries} when retries > 4 ->
        IO.puts "[Domains] Errored out after 5 retries on #{domain}"
      {crawl_id, domain, retries} ->
        IO.puts "[Domains] found a domain to check: #{domain}"
        case Scraper.Core.check_domain(domain) do
          :error ->
            Store.Domains.push(crawl_id, domain, retries + 1)
          :registered ->
            # status = false, add to database
            insert(crawl_id, domain, false)
          :available ->
            # status = true, add to database
            insert(crawl_id, domain, true)
        end
        Workers.Domains.update(id, {:busy, domain})
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

  defp insert(crawl_id, domain, status) do
    case Repo.insert(Domain.changeset(%Domain{}, %{domain: domain, status: status, crawl_id: crawl_id})) do
      {:ok, _} ->
        IO.puts "[Domains] Inserted #{domain}"
      {:error, _} ->
        IO.puts "[Domains] Error inserting #{domain}, probably a duplicate"
    end
  end
end
