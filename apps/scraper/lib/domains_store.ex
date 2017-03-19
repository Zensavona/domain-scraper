defmodule Scraper.Store.Domains do
  @doc """
  Starts a new bucket.

  Domains look like this: {crawl_id, domain, retries}
  """
  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @doc """
  Gets a value from the `bucket` by `key`.
  """
  def get_list do
    Agent.get(__MODULE__, &(&1))
  end
  def get_list(crawl_id) do
    # filter out if the crawl_id doesn't match
    Agent.get(__MODULE__, &(Enum.filter(&1, fn(d) ->
      case d do
        {id, _, _} when id == crawl_id ->
          true
        _ ->
          false
      end
    end)))
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def push(crawl_id, domain, retries \\ 0) do
    list = crawl_id |> get_list() |> Enum.map(fn({crawl_id, domain, _r}) -> {crawl_id, domain} end)
    if !Enum.member?(list, {crawl_id, domain}) do
      Agent.update(__MODULE__, fn(list) -> [{crawl_id, domain, retries} | list] end)
    end
  end

  def pop do
    list = get_list()
    [head | tail] = Enum.reverse(list)
    Agent.update(__MODULE__, fn() -> Enum.reverse(tail) end)
    head
  end

  def pop(amount) do
    case get_list() do
      # there are more in the list than the amount requested
      list when length(list) >= amount and amount > 0 ->
        Enum.map(1..amount, fn() -> pop() end)
      # there are less in the list than the amount requested, but the list is not empty
      list when length(list) > 0 and amount > 0 ->
        Enum.map(1..length(list), fn() -> pop() end)
      # the list is empty
      _ ->
      []
    end
  end
end