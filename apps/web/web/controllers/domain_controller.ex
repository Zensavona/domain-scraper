defmodule Web.DomainController do
  use Web.Web, :controller
  alias Web.Domain

  def action(conn, _) do
    apply(__MODULE__, action_name(conn),
          [conn, conn.params, conn.assigns.current_user])
  end

  def index(conn, %{"sort" => sort_by}, current_user) do
    sort_by = String.to_atom(sort_by)
    domains = current_user |> Domain.by_id_for_user(sort_by) |> Repo.all |> Repo.preload(:crawl)
    render(conn, "index.html", domains: domains, sort_by: sort_by)
  end

  def index(conn, _params, current_user) do
    sort_by = :da
    domains = current_user |> Domain.by_id_for_user(sort_by) |> Repo.all
    render(conn, "index.html", domains: domains, sort_by: sort_by)
  end
end
