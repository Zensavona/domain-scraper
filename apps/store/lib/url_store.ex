defmodule Store.ToCrawl do
  @set_name "to_crawl"

  require DogStatsd

  def exists?(crawl_id, url) do
    case Store.Redix.command(["SISMEMBER", "#{@set_name}:#{crawl_id}", "#{url}"]) do
      {:ok, 1} ->
        true
      {:ok, 0} ->
        false
    end
  end

  def push(crawl_id, urls) when is_list(urls) do
    urls = urls |> Enum.reject(&is_nil/1) |> Enum.map(&String.trim/1) |> Enum.filter(fn(u) -> String.length(u) >= 4 end)

    if length(urls) >= 1 do
      DogStatsd.time(:dogstatsd, "store.to_crawl.write_time") do
        commands = urls |> Enum.reject(&Store.Crawled.exists?(crawl_id, &1)) |> Enum.map(fn(url) -> ["SADD", "#{@set_name}:#{crawl_id}", url] end)
        if (length(commands) > 0) do
          Store.Redix.pipeline(commands)
          DogStatsd.increment(:dogstatsd, "store.to_crawl.write")
        end
      end
    end
  end

  def push(crawl_id, url) do
    DogStatsd.time(:dogstatsd, "store.to_crawl.write_time") do
      if !Store.Crawled.exists?(crawl_id, url) && !Store.ToCrawl.exists?(crawl_id, url) do
        Store.Redix.command(["SADD", "#{@set_name}:#{crawl_id}", url])
        DogStatsd.increment(:dogstatsd, "store.to_crawl.write")
      else
        IO.puts "[ToCrawl] Found duplicate: #{url}"
        DogStatsd.increment(:dogstatsd, "store.to_crawl.duplicate")
      end
    end
  end

  defp list_length do
    case Store.Redix.command(["SCARD", @set_name]) do
      {:ok, length} ->
        length
    end
  end

  def list_length(crawl_id) do
    case Store.Redix.command(["SCARD", "#{@set_name}:#{crawl_id}"]) do
      {:ok, nil} ->
        0
      {:ok, members} ->
         members
    end
  end
end

defmodule Store.Crawled do
  @set_name "crawled"

  def clear(crawl_id) do
     Store.Redix.command(["DEL", "#{@set_name}_#{crawl_id}"])
  end

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
    case Store.Redix.command(["SCARD", "#{@set_name}_#{crawl_id}"]) do
      {:ok, nil} ->
        0
      {:ok, members} ->
         members
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
