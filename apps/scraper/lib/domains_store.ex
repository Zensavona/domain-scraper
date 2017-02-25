# defmodule Scraper.Store.DomainsToCheck do
#   use GenServer

#   ######
#   ## External API
#   ##

#   def start_link() do
#     GenServer.start_link(__MODULE__, [], name: __MODULE__)
#   end

#   def get_list do
#     GenServer.call(__MODULE__, :get_to_check_list)
#   end

#   def push(url) do
#     GenServer.cast(__MODULE__, {:push_to_check_list, url})
#   end

#   def pop do
#     GenServer.call(__MODULE__, :pop_to_check_list)
#   end

#   def handle_cast({:push_to_check_list, domain}, current_crawl_list) do
#     updated_crawl_list = [domain | current_crawl_list] |> Enum.uniq
#     {:noreply, updated_crawl_list}
#   end

#   def handle_call(:pop_to_check_list, _from, current_crawl_list) do
#     case current_crawl_list do
#       [] ->
#         {:reply, {:none}, []}
#       list ->
#         [head | tail] = Enum.reverse(list)
#         {:reply, {:ok, head}, Enum.reverse(tail)}
#     end
#   end

#   def handle_call(:get_to_check_list, _from, state) do
#     {:reply, state, state}
#   end
# end

defmodule Scraper.Store.Domains do
  @doc """
  Starts a new bucket.
  """
  def start_link(seed_url) do
    Agent.start_link(fn -> [] end, name: :"#{seed_url}_domains")
  end

  @doc """
  Gets a value from the `bucket` by `key`.
  """
  def get_list(seed_url) do
    Agent.get(:"#{seed_url}_domains", &(&1))
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def push(seed_url, value) do
    Agent.update(:"#{seed_url}_domains", fn(list) -> Enum.uniq([value | list]) end)
  end
end
