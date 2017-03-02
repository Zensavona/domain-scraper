defmodule Scraper.Store.ToCrawl do
  @doc """
  Starts a new bucket.

  Domains look like this: {crawl_id, url, retries}
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
  def push(crawl_id, url, retries \\ 0) do
    to_crawl_list = crawl_id |> get_list |> Enum.map(fn({crawl_id, url, _r}) -> {crawl_id, url} end)
    crawled_list = crawl_id |> Scraper.Store.Crawled.get_list |> Enum.map(fn({crawl_id, url, _r}) -> {crawl_id, url} end)
    list = to_crawl_list ++ crawled_list
    
    if !Enum.member?(list, {crawl_id, url}) do
      Agent.update(__MODULE__, fn(list) -> [{crawl_id, url, retries} | list] end)
    end
  end

  def pop do
    list = get_list
    [head | tail] = Enum.reverse(list)
    Agent.update(__MODULE__, fn(_) -> Enum.reverse(tail) end)
    head
  end

  def pop(amount) do
    case get_list() do
      # there are more in the list than the amount requested
      list when length(list) >= amount and amount > 0 ->
        Enum.map(1..amount, fn(_) -> pop() end)
      # there are less in the list than the amount requested, but the list is not empty
      list when length(list) > 0 and amount > 0 ->
        Enum.map(1..length(list), fn(_) -> pop() end)
      # the list is empty
      _ ->
      []
    end
  end
end
