defmodule Workers.Domain do

  require DogStatsd
  require Logger
  alias Web.Repo
  alias Web.Domain

  def worker do
    case Scheduler.pop_domain do
      :empty ->
        :timer.sleep(1000)
      {crawl_id, domain} ->
        DogStatsd.time(:dogstatsd, "worker.domain.time") do
          Logger.info "[Domains] found a domain to check: #{domain} (#{crawl_id})"
          case Scraper.Core.check_domain(domain) do
            {:error, nil} ->
              insert(crawl_id, domain, false)
              DogStatsd.increment(:dogstatsd, "worker.domain.checked")
              DogStatsd.increment(:dogstatsd, "worker.domain.error")
            {:registered, nil} ->
              # status = false, add to database
              insert(crawl_id, domain, false)
              DogStatsd.increment(:dogstatsd, "worker.domain.checked")
              DogStatsd.increment(:dogstatsd, "worker.domain.registered")
            {:available, meta} ->
              # status = true, add to database
              insert(crawl_id, domain, true, meta)
              DogStatsd.increment(:dogstatsd, "worker.domain.checked")
              DogStatsd.increment(:dogstatsd, "worker.domain.available")
          end
        end
    end
    worker()
  end

  defp insert(crawl_id, domain, status, meta \\ %{}) do
    if (!Store.DomainsChecked.exists?(crawl_id, domain)) do
      data = Map.merge(%{"domain" => domain, "status" => status, "crawl_id" => crawl_id}, Enum.into(meta, %{}))
      case Repo.insert(Domain.changeset(%Domain{}, data)) do
        {:ok, _} ->
          Store.DomainsChecked.push(crawl_id, domain)
          Logger.info "[Domains] Inserted #{domain}"
        {:error, _} ->
          Logger.info "[Domains] Error inserting #{domain}, probably a duplicate (Repo rejection)"
      end
    else
      Logger.info "[Domains] Error inserting #{domain}, probably a duplicate (Found in Store)"
    end
  end
end
