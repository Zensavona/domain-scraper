defmodule Store.Domains do
  use GenServer

  alias Web.Repo
  alias Web.Domain
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

  def handle_cast({ :push, {crawl_id, domain, retries} }, current_stack) do
    domains = current_stack |> filter_by_id(crawl_id) |> Enum.map(fn({crawl_id, domain, _r}) -> {crawl_id, domain} end)
    domains_from_db = Repo.all(from d in Domain, select: {d.crawl_id, d.domain}, where: d.domain == ^domain)
    list = domains ++ domains_from_db

    if !Enum.member?(list, {crawl_id, domain}) do
      { :noreply, [ {crawl_id, domain, retries} | current_stack ] }
    else
      IO.puts "[Domains] Found duplicate: #{domain}"
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
