defmodule Scraper.Store.Crawled do
  @doc """
  Starts a new bucket.
  """
  def start_link(seed_url) do
    Agent.start_link(fn -> [] end, name: :"#{seed_url}_crawled")
  end

  @doc """
  Gets a value from the `bucket` by `key`.
  """
  def get_list(seed_url) do
    Agent.get(:"#{seed_url}_crawled", &(&1))
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def push(seed_url, value) do
    Agent.update(:"#{seed_url}_crawled", fn(list) -> Enum.uniq([value | list]) end)
  end
end
