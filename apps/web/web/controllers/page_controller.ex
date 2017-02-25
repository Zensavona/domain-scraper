defmodule Web.PageController do
  use Web.Web, :controller
  require IEx

  def index(conn, _params) do
    try do
      Scraper.Store.Crawled.get_list
    catch
      :exit, _ -> Scraper.init("http://forum.bodybuilding.com")
    end

    crawled = Scraper.Store.Crawled.get_list
    domains = Scraper.Store.DomainsToCheck.get_list

    render conn, "index.html", crawled: crawled, domains: domains
  end
end
