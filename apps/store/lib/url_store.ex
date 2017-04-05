defmodule Store.ToCrawl do
  require DogStatsd
  @set_name "to_crawl"

  def pop do
    case Store.Redix.command(["SPOP", @set_name]) do
      {:ok, nil} ->
        :empty
      {:ok, entry} ->
        DogStatsd.increment(:dogstatsd, "store.to_crawl.read")
        [crawl_id, url] = String.split(entry, "|")
        {crawl_id, url}
    end
  end

  def push(crawl_id, urls) when is_list(urls) do
    DogStatsd.time(:dogstatsd, "store.to_crawl.write_time") do
      commands = urls |> Enum.reject(&Store.Crawled.exists?(crawl_id, &1)) |> Enum.map(fn(url) -> ["SADD", @set_name, "#{crawl_id}|#{url}"] end)
      if (length(commands) > 0) do
        DogStatsd.increment(:dogstatsd, "store.to_crawl.write")
        Store.Redix.pipeline(commands)
      end
    end
  end

  def push(crawl_id, url) do
    DogStatsd.time(:dogstatsd, "store.to_crawl.write_time") do
      if !Store.Crawled.exists?(crawl_id, url) do
        DogStatsd.increment(:dogstatsd, "store.to_crawl.write")
        Store.Redix.command(["SADD", @set_name, "#{crawl_id}|#{url}"])
      else
        DogStatsd.increment(:dogstatsd, "store.to_crawl.duplicate")
        IO.puts "[ToCrawl] Found duplicate: #{url}"
      end
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
