defmodule Scraper.Store.Crawled do
  use GenServer

  ######
  ## External API
  ##

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_list do
    GenServer.call(__MODULE__, :get_crawled_list)
  end

  def push(url) do
    GenServer.cast(__MODULE__, {:push_crawled_list, url})
  end

  def pop do
    GenServer.call(__MODULE__, :pop_crawled_list)
  end

  def handle_cast({:push_crawled_list, domain}, current_crawl_list) do
    updated_crawl_list = [domain | current_crawl_list] |> Enum.uniq
    {:noreply, updated_crawl_list}
  end

  def handle_call(:pop_crawled_list, _from, current_crawl_list) do
    [head | tail] = Enum.reverse(current_crawl_list)
    {:reply, head, Enum.reverse(tail)}
  end

  def handle_call(:get_crawled_list, _from, state) do
    {:reply, state, state}
  end
end
