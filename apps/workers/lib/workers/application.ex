defmodule Workers.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

     url_workers =  1..1000 |> Enum.map(fn (i) -> supervisor(Workers.UrlSupervisor, [i], [id: {Workers.UrlSupervisor, i}, restart: :permanent]) end)
     domain_workers = 1..500 |> Enum.map(fn (i) -> supervisor(Workers.DomainSupervisor, [i], [id: {Workers.DomainSupervisor, i}, restart: :permanent]) end)

    opts = [strategy: :one_for_one, name: Workers.Supervisor]
    Supervisor.start_link(url_workers ++ domain_workers, opts)
  end
end

defmodule Workers.UrlSupervisor do
  def start_link(id) do
    import Supervisor.Spec, warn: false

    children = [worker(Task, [&Workers.Url.worker/0], [id: {Workers.Url, id}, restart: :permanent])]

    opts = [strategy: :one_for_one, name: :"url_supervisor_#{id}"]
    Supervisor.start_link(children, opts)
  end
end

defmodule Workers.DomainSupervisor do
  def start_link(id) do
    import Supervisor.Spec, warn: false

    children = [worker(Task, [&Workers.Domain.worker/0], [id: {Workers.Domain, id}, restart: :permanent])]

    opts = [strategy: :one_for_one, name: :"domain_supervisor_#{id}"]
    Supervisor.start_link(children, opts)
  end
end
