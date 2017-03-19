defmodule Store.ToCrawl do
  use GenServer

  alias Web.Repo
  alias Web.Url
  import Ecto.Query

# API

  def start_link(current_stack) do
    GenServer.start_link(__MODULE__, current_stack, name: __MODULE__)
  end

  def pop do
    GenServer.call(__MODULE__, :pop)
  end

  def push(crawl_id, url, retries \\ 0) do
    GenServer.cast(__MODULE__, { :push, {crawl_id, url, retries} })
  end

  def get_list do
    GenServer.call(__MODULE__, :get_list)
  end

  def get_list(crawl_id) do
    Enum.filter(get_list, fn(item) ->
      case item do
        {id, _url, _retries} when crawl_id == id ->
          true
        _ ->
          false
      end
    end)
  end

# Implementation

  def handle_call(:get_list, _from, current_stack) do
    {:reply, current_stack, current_stack}
  end

  def handle_call(:pop, _from, current_stack) when current_stack == [] do
    { :reply, :empty, [] }
  end
  def handle_call(:pop, _from, current_stack) do
    [ top | tail ] = Enum.reverse(current_stack)
    { :reply, top, Enum.reverse(tail) }
  end

  def handle_cast({ :push, {crawl_id, url, retries} }, current_stack) do
    to_crawl_list = current_stack |> filter_by_id(crawl_id) |> Enum.map(fn({crawl_id, url, _r}) -> {crawl_id, url} end)
    crawled_list = Repo.all(from u in Url, select: {u.crawl_id, u.url}, where: u.url == ^url)
    # crawled_list = crawl_id |> Store.Crawled.get_list |> Enum.map(fn({crawl_id, url, _r}) -> {crawl_id, url} end)
    list = to_crawl_list  ++ crawled_list

    if !Enum.member?(list, {crawl_id, url}) do
      { :noreply, [ {crawl_id, url, retries} | current_stack ] }
    else
      IO.puts "[ToCrawl] Found duplicate: #{url}"
      { :noreply, current_stack }
    end
  end

  defp filter_by_id(list, crawl_id) do
    Enum.filter(list, fn(item) ->
      case item do
        {id, _url, _retries} when crawl_id == id ->
          true
        _ ->
          false
      end
    end)
  end
end
