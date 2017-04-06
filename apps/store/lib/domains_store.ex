defmodule Store.Domains do
  @set_name "domains_to_check"

  require DogStatsd

  def push(crawl_id, domain) do
    case domain do
      nil ->
         IO.puts "[Domains] Bad Domain: #{domain}"
      domain ->
        domain = domain |> String.trim
        if (!is_nil(domain) && String.length(domain) >= 4) do
          DogStatsd.time(:dogstatsd, "store.domains.write_time") do
            case Store.DomainsChecked.exists?(crawl_id, domain) do
              false ->
                DogStatsd.increment(:dogstatsd, "store.domains.written")
                Store.Redix.command(["SADD", "#{@set_name}:#{crawl_id}", domain])
              _ ->
              DogStatsd.increment(:dogstatsd, "store.domains.duplicate")
              IO.puts "[Domains] Found duplicate: #{domain}"
            end
          end
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

defmodule Store.DomainsChecked do
  @set_name "domains_checked"

  def clear(crawl_id) do
     Store.Redix.command(["DEL", "#{@set_name}:#{crawl_id}"])
  end

  def exists?(crawl_id, domain) do
    case Store.Redix.command(["SISMEMBER", "#{@set_name}:#{crawl_id}", domain]) do
      {:ok, 1} ->
        true
      {:ok, 0} ->
        false
    end
  end

  def push(crawl_id, domain) do
    Store.Redix.command(["SADD", "#{@set_name}:#{crawl_id}", domain])
  end

  def list_length(crawl_id) do
    case Store.Redix.command(["SCARD", "#{@set_name}:#{crawl_id}"]) do
      {:ok, nil} ->
        0
      {:ok, members} ->
         members
    end
  end

  def get_list(crawl_id) do
    case Store.Redix.command(["SMEMBERS", "#{@set_name}:#{crawl_id}"]) do
      {:ok, nil} ->
        []
      {:ok, members} ->
        members
    end
  end
end
