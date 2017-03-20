defmodule Workers.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

     children = [
      supervisor(Workers.UrlSupervisor, []),
      supervisor(Workers.DomainSupervisor, [])
     ]

    opts = [strategy: :one_for_one, name: Workers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule Workers.UrlSupervisor do
  def start_link do
    import Supervisor.Spec, warn: false

    children = 1..50 |> Enum.to_list |> Enum.map(fn (i) -> worker(Task, [&Workers.Url.worker/0], [id: String.to_atom("url_worker_#{i}")]) end)

    opts = [strategy: :one_for_one, name: Workers.UrlSupervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule Workers.DomainSupervisor do
  def start_link do
    import Supervisor.Spec, warn: false

    children = 1..50 |> Enum.to_list |> Enum.map(fn (i) -> worker(Task, [&Workers.Domain.worker/0], [id: String.to_atom("domain_worker_#{i}")]) end)

    opts = [strategy: :one_for_one, name: Workers.DomainSupervisor]
    Supervisor.start_link(children, opts)
  end
end
