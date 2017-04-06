defmodule Workers.Domain do

  require DogStatsd
  alias Web.Repo
  alias Web.Domain


  def worker do
    DogStatsd.time(:dogstatsd, "worker.domain.time") do
      case Scheduler.pop_domain do
        :empty ->
          # IO.puts "[Domain] none found, waiting..."
          :timer.sleep(1000)
        {crawl_id, domain} ->
          IO.puts "[Domains] found a domain to check: #{domain} (#{crawl_id})"
          case Scraper.Core.check_domain(domain) do
            :error ->
              DogStatsd.increment(:dogstatsd, "worker.domain.checked")
              DogStatsd.increment(:dogstatsd, "worker.domain.error")
              insert(crawl_id, domain, false)
            :registered ->
              DogStatsd.increment(:dogstatsd, "worker.domain.checked")
              DogStatsd.increment(:dogstatsd, "worker.domain.registered")
              # status = false, add to database
              insert(crawl_id, domain, false)
            :available ->
              DogStatsd.increment(:dogstatsd, "worker.domain.checked")
              DogStatsd.increment(:dogstatsd, "worker.domain.available")
              # status = true, add to database
              insert(crawl_id, domain, true)
          end
      end
    end
    worker()
  end

  defp insert(crawl_id, domain, status) do
    if (!Store.DomainsChecked.exists?(crawl_id, domain)) do
      case Repo.insert(Domain.changeset(%Domain{}, %{domain: domain, status: status, crawl_id: crawl_id})) do
        {:ok, _} ->
          Store.DomainsChecked.push(crawl_id, domain)
          IO.puts "[Domains] Inserted #{domain}"
        {:error, _} ->
          IO.puts "[Domains] Error inserting #{domain}, probably a duplicate (Repo rejection)"
      end
    else
      IO.puts "[Domains] Error inserting #{domain}, probably a duplicate (Found in Store)"
    end
  end
end
