defmodule Scraper.Store.Crawled do
  @doc """
  Starts a new bucket.
  """
  def start_link(id) do
    Agent.start_link(fn -> [] end, name: :"#{id}_crawled")
  end

  @doc """
  Gets a value from the `bucket` by `key`.
  """
  def get_list(id) do
    Agent.get(:"#{id}_crawled", &(&1))
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def push(id, value) do
    Agent.update(:"#{id}_crawled", fn(list) -> Enum.uniq([value | list]) end)
  end
end
