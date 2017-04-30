defmodule Web.PageController do
  use Web.Web, :controller
  require IEx

  def index(conn, _params) do
    crawled = [] # Scraper.Store.Crawled.get_list
    domains = [] # Scraper.Store.Domains.get_list

    render conn, "index.html", crawled: crawled, domains: domains
  end
end
