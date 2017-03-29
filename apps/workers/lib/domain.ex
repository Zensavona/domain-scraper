defmodule Workers.Domain do

  alias Web.Repo
  alias Web.Domain


  def worker do
    case Store.Domains.pop do
      :empty ->
        # IO.puts "[Domain] none found, waiting..."
        :timer.sleep(1000)
      {crawl_id, domain} ->
        IO.puts "[Domains] found a domain to check: #{domain}"
        case Scraper.Core.check_domain(domain) do
          :error ->
            insert(crawl_id, domain, false)
          :registered ->
            # status = false, add to database
            insert(crawl_id, domain, false)
          :available ->
            # status = true, add to database
            insert(crawl_id, domain, true)
        end
    end
    worker()
  end

  defp insert(crawl_id, domain, status) do
    case Repo.insert(Domain.changeset(%Domain{}, %{domain: domain, status: status, crawl_id: crawl_id})) do
      {:ok, _} ->
        IO.puts "[Domains] Inserted #{domain}"
      {:error, _} ->
        IO.puts "[Domains] Error inserting #{domain}, probably a duplicate"
    end
  end
end
