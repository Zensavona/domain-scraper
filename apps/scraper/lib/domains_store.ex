defmodule Scraper.Store.Domains do
  @doc """
  Starts a new bucket.
  """
  def start_link(id) do
    Agent.start_link(fn -> [] end, name: :"#{id}_domains")
  end

  @doc """
  Gets a value from the `bucket` by `key`.
  """
  def get_list(id) do
    Agent.get(:"#{id}_domains", &(&1))
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def push(id, value) do
    {domain, _} = value
    list = Enum.map(get_list(id), fn(v) ->
      {domain, _} = v
      domain
    end)

    if !Enum.member?(list, domain) do
      Agent.update(:"#{id}_domains", fn(list) -> [value | list] end)
    end
  end
end
