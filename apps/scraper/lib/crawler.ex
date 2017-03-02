# gets urls to crawl from the queue, they look like {url, crawl_id, retries}
defmodule Scraper.Crawler.A do
  use GenStage

  def start_link(:ok) do
    GenStage.start_link(__MODULE__, [])
  end

  def init(initial_urls) do
    Scraper.Store.Domains.start_link()
    Scraper.Store.ToCrawl.start_link()
    Scraper.Store.Crawled.start_link()
    {:producer, initial_urls}
  end

  def get_more(amount) do
    case Scraper.Store.ToCrawl.get_list() do
      events when length(events) > 0 ->
        IO.puts "[Crawler] found #{length(events)} URLS"
        Scraper.Store.ToCrawl.pop(amount)
      events ->
        IO.puts "[Crawler] Waiting for more URLS... (Demand: #{amount}, Found: #{length(events)})"
        :timer.sleep(1000)
        get_more(amount)
    end
  end

  def handle_demand(demand, total_crawled) when demand > 0 do
    IO.puts "[Crawler] Demand: #{demand}"
    events = get_more(demand)
    {:noreply, events, total_crawled}
  end
end

##########################

defmodule QueueBroadcaster do
  use GenStage

  @doc "Starts the broadcaster."
  def start_link() do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Sends an event and returns only after the event is dispatched."
  def sync_notify(event, timeout \\ 10000) do
    IO.inspect event
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  ## Callbacks

  def init(:ok) do
    {:producer, {:queue.new, 0}, dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_call({:notify, event}, from, {queue, pending_demand}) do
    queue = :queue.in({from, event}, queue)
    dispatch_events(queue, pending_demand, [])
  end

  def handle_demand(incoming_demand, {queue, pending_demand}) do
    dispatch_events(queue, incoming_demand + pending_demand, [])
  end

  defp dispatch_events(queue, 0, events) do
    {:noreply, Enum.reverse(events), {queue, 0}}
  end
  defp dispatch_events(queue, demand, events) do
    case :queue.out(queue) do
      {{:value, {from, event}}, queue} ->
        GenStage.reply(from, :ok)
        dispatch_events(queue, demand - 1, [event | events])
      {:empty, queue} ->
        {:noreply, Enum.reverse(events), {queue, demand}}
    end
  end
end

# crawls them, mapping them concurrently into {:crawled, result}, {:to_crawl, result} (incrementing retry if negative result)
defmodule Scraper.Crawler.B do
  use GenStage

  def start_link(number) do
    GenStage.start_link(B, number)
  end

  def init(number) do
    {:producer_consumer, number, subscribe_to: [{Scraper.Crawler.A, min_demand: 0, max_demand: 1}]}
  end

  def handle_events(events, _from, number) do
    IO.puts "[Crawler] Events: #{length(events)}"
    # events = Enum.map(events, & &1 * number)
    more_events =
     events
     |> Enum.map(&(Task.async(fn -> process(&1) end)))
     |> Enum.map(&Task.await/1)
     |> List.flatten
    {:noreply, more_events, number}
  end

  def process(event) do
    case event do
      {crawl_id, url, retries} when retries <= 3 ->
        url |> Scraper.Core.url_to_urls_and_domains |> categorise(crawl_id, retries) |> List.insert_at(-1, {:crawled, {crawl_id, url, :ok}})
      {crawl_id, url, _} ->
        [{:crawled, {crawl_id, url, :error}}]
    end
  end

  def categorise(response, crawl_id, retries) do
    case response do
      {:ok, urls, domains} ->
        urls = Enum.map(urls, &({:to_crawl, {crawl_id, &1, 0}}))
        domains = Enum.map(domains, &({:domain, {crawl_id, &1, 0}}))
        urls ++ domains
      {:error, url} ->
        [{:to_crawl, {crawl_id, url, retries + 1}}]
    end
  end
end

# saves good results to the database and appends
defmodule Scraper.Crawler.C do
  use GenStage

  def start_link() do
    GenStage.start_link(C, :ok)
  end

  def init(:ok) do
    {:consumer, :the_state_does_not_matter, subscribe_to: [{Scraper.Crawler.B, min_demand: 0, max_demand: 1}]}
  end

  def handle_events(events, _from, state) do
    # Wait for a second.
    # :timer.sleep(100)

    Enum.each(events, fn(e) ->
      case e do
        {:crawled, {crawl_id, url, :error}} ->
          IO.puts "[Crawler] Error on #{url}"
          Scraper.Store.Crawled.push(crawl_id, url, 0)
        {:crawled, {crawl_id, url, :ok}} ->
          IO.puts "[Crawler] Success on #{url}"
          Scraper.Store.Crawled.push(crawl_id, url, 0)
        {:to_crawl, {crawl_id, url, retries} = event} ->
          IO.puts "[Crawler] Adding to list: #{url}"
          Scraper.Store.ToCrawl.push(crawl_id, url, retries)
          # QueueBroadcaster.sync_notify({crawl_id, url, retries})
        {:domain, {crawl_id, domain, retries}} ->
          IO.puts "[Crawler] Found domain #{domain}"
      end
    end)

    # We are a consumer, so we would never emit items.
    {:noreply, [], state}
  end
end

defmodule Scraper.Crawler do
  def start do
    # QueueBroadcaster.start_link()
    {:ok, a} = GenStage.start_link(Scraper.Crawler.A, [], name: Scraper.Crawler.A)  # starting from zero
    {:ok, b} = GenStage.start_link(Scraper.Crawler.B, 0, name: Scraper.Crawler.B)  # multiply by 2
    {:ok, c} = GenStage.start_link(Scraper.Crawler.C, :ok)   # state does not matter
  end

  def crawl(crawl_id, url) do
    # QueueBroadcaster.sync_notify({crawl_id, url, 0})
    Scraper.Store.ToCrawl.push crawl_id, url
  end
end
