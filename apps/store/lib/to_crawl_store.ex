defmodule Store.ToCrawl do
  @set_name "to_crawl"

  def pop do
    case Store.Redix.command(["SPOP", @set_name]) do
      {:ok, nil} ->
        :empty
      {:ok, entry} ->
        [crawl_id, url] = String.split(entry, "|")
        {crawl_id, url}
    end
  end

  def push(crawl_id, url) do
    if !Store.Crawled.exists?(crawl_id, url) do
      Store.Redix.command(["SADD", @set_name, "#{crawl_id}|#{url}"])
    else
      IO.puts "[ToCrawl] Found duplicate: #{url}"
    end
  end

  def list_length do
    case Store.Redix.command(["SCARD", @set_name]) do
      {:ok, length} ->
        length
    end
  end

  def list_length(crawl_id) do
    case Store.Redix.command(["SMEMBERS", @set_name]) do
      {:ok, nil} ->
        0
      {:ok, members} ->
         members |> Enum.filter(fn(i) -> List.first(String.codepoints(i)) == to_string(crawl_id) end) |> length
    end
  end
end

defmodule Store.Crawled do
  @set_name "crawled"

  # todo: clear(crawl_id) func

  def exists?(crawl_id, url) do
    case Store.Redix.command(["SISMEMBER", "#{@set_name}_#{crawl_id}", "#{url}"]) do
      {:ok, 1} ->
        true
      {:ok, 0} ->
        false
    end
  end

  def push(crawl_id, url) do
    Store.Redix.command(["SADD", "#{@set_name}_#{crawl_id}", "#{url}"])
  end

  def list_length(crawl_id) do
    case Store.Redix.command(["SMEMBERS", "#{@set_name}_#{crawl_id}"]) do
      {:ok, nil} ->
        0
      {:ok, members} ->
         members |> length
    end
  end

  def get_list(crawl_id) do
    case Store.Redix.command(["SMEMBERS", "#{@set_name}_#{crawl_id}"]) do
      {:ok, nil} ->
        []
      {:ok, members} ->
        members |> Enum.map(fn(i) -> i |> String.split("|") |> List.last end)
    end
  end
end












defmodule Store.ToCrawlol do
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
