defmodule Web.PageController do
  use Web.Web, :controller
  require IEx

  def index(conn, _params) do
    crawled = []
    domains = []

    render conn, "index.html", crawled: crawled, domains: domains
  end
end
