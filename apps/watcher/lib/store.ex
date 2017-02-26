defmodule Watcher.Store do
  @doc """
  Starts a new bucket.
  """
  def start_link() do
    # run Watcher.watch every 10 seconds forever
    :timer.apply_interval(:timer.seconds(10), Watcher, :watch, [])
    Agent.start_link(fn -> [] end, name: __MODULE__)
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
  def push(value) do
    Agent.update(__MODULE__, fn(list) -> [value | list] end)
  end

  def remove(id) do
    crawls = Agent.get(__MODULE__, &(&1))

    crawl = Enum.find(crawls, fn(c) ->
      {the_id, _, _} = c
      the_id == id
    end)

    crawls_left = Enum.reject(crawls, fn(c) -> c == crawl end)

    Agent.update(__MODULE__, fn(_) -> crawls_left end)
  end

  def update(id, value) do
    remove id
    push value
  end
end
