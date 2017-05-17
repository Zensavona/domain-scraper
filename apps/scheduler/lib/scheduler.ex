defmodule Scheduler do
  @moduledoc """
  Documentation for Scheduler.
  """
  require Logger
  @set_name "in_progress"

  @doc """
  Add a crawl to the `in_progress` set, which will prompt the scheduler to fetch urls and domains for it
  """
  def add_crawl(id) do
    Store.Redix.command(["SADD", @set_name, id])
  end

  @doc """
  Remove a crawl from the `in_progress` set, which will stop the scheduler from fetching urls and domains for it
  """
  def remove_crawl(id) do
     Store.Redix.command(["SREM", @set_name, id])
  end

  def crawls_in_progress do
    Store.Redix.command(["SMEMBERS", @set_name])
  end

  @doc """
  Get a url from a random in progress crawl
  """
  def pop_url do
    case crawls_in_progress do
      {:ok, nil} ->
         :empty
      {:error, :timeout} ->
        Logger.info "[Scheduler] Redis timeout..."
        :empty
      {:ok, crawls} ->
        crawls_with_members = crawls
          |> Enum.map(fn(c) -> {c, Store.Redix.command(["SCARD", "to_crawl:#{c}"])} end)
          |> Enum.filter(fn({_crawl, {result, _card}}) -> result == :ok end)
          |> Enum.map(fn({crawl_id, {:ok, cardinality}}) -> {crawl_id, cardinality} end)
          |> Enum.reject(fn({_crawl_id,  cardinality}) -> is_nil(cardinality) || cardinality == 0 end)
        if (length(crawls_with_members) >= 1) do
          {crawl_id, _card} = Enum.random(crawls_with_members)
          case Store.Redix.command(["SPOP", "to_crawl:#{crawl_id}"]) do
            {:ok, nil} ->
              Logger.info "[Scheduler] Popped Url, it was nil"
              :empty
            {:ok, url} ->
              Logger.info "[Scheduler] Popped Url #{url}"
              {crawl_id, url}
            {:error, :timeout} ->
              Logger.info "[Scheduler] Redis timeout..."
              :empty
          end
        else
          :empty
        end
    end
  end

  @doc """
  Get a domain from a random in progress crawl
  """
  def pop_domain do
    case crawls_in_progress do
      {:ok, nil} ->
         :empty
      {:error, :timeout} ->
         Logger.info "[Scheduler] Redis timeout..."
         :empty
      {:ok, crawls} ->
        crawls_with_members = crawls
          |> Enum.map(fn(c) -> {c, Store.Redix.command(["SCARD", "domains_to_check:#{c}"])} end)
          |> Enum.filter(fn({_crawl, {result, _card}}) -> result == :ok end)
          |> Enum.map(fn({crawl_id, {:ok, cardinality}}) -> {crawl_id, cardinality} end)
          |> Enum.reject(fn({_crawl_id,  cardinality}) -> is_nil(cardinality) || cardinality == 0 end)
        if (length(crawls_with_members) >= 1) do
          {crawl_id, _card} = Enum.random(crawls_with_members)
          case Store.Redix.command(["SPOP", "domains_to_check:#{crawl_id}"]) do
            {:ok, nil} ->
              Logger.info "[Scheduler] Popped Domain, it was nil"
              :empty
            {:ok, domain} ->
              Logger.info "[Scheduler] Popped Domain #{domain}"
              {crawl_id, domain}
            {:error, :timeout} ->
              Logger.info "[Scheduler] Redis timeout..."
              :empty
          end
        else
          :empty
        end
    end
  end

end
