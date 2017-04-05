defmodule Store.Domains do
  @set_name "domains"

  require DogStatsd

  def pop do
    DogStatsd.time(:dogstatsd, "store.domains.read_time") do
      case Store.Redix.command(["SPOP", @set_name]) do
        {:ok, nil} ->
          :empty
        {:ok, entry} ->
          DogStatsd.increment(:dogstatsd, "store.domains.read")
          [crawl_id, domain] = String.split(entry, "|")
          {crawl_id, domain}
      end
    end
  end

  def push(crawl_id, domain) do
    DogStatsd.time(:dogstatsd, "store.domains.write_time") do
      case Store.DomainsChecked.exists?(crawl_id, domain) do
        false ->
          DogStatsd.increment(:dogstatsd, "store.domains.written")
          Store.Redix.command(["SADD", @set_name, "#{crawl_id}|#{domain}"])
        _ ->
        DogStatsd.increment(:dogstatsd, "store.domains.duplicate")
        IO.puts "[Domains] Found duplicate: #{domain}"
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

defmodule Store.DomainsChecked do
  @set_name "domains_checked"

  # todo: clear(crawl_id) func

  def exists?(crawl_id, domain) do
    case Store.Redix.command(["SISMEMBER", "#{@set_name}_#{crawl_id}", "#{domain}"]) do
      {:ok, 1} ->
        true
      {:ok, 0} ->
        false
    end
  end

  def push(crawl_id, domain) do
    Store.Redix.command(["SADD", "#{@set_name}_#{crawl_id}", "#{domain}"])
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
