defmodule Web.DomainController do
  use Web.Web, :controller
  alias Web.Domain

  def action(conn, _) do
    apply(__MODULE__, action_name(conn),
          [conn, conn.params, conn.assigns.current_user])
  end

  def index(conn, _params, current_user) do
    domains = current_user |> Domain.by_id_for_user |> Repo.all
    render(conn, "index.html", domains: domains)
  end
end
