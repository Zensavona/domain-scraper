defmodule Store.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Store.Worker.start_link(arg1, arg2, arg3)
      # worker(Store.ToCrawl, [[]]),
      # worker(Store.Domains, [[]]),
    ]

    pool_size = 10
    redix_workers = for i <- 0..(pool_size - 1) do
      worker(Redix, [[], [name: :"redix_#{i}"]], id: {Redix, i})
    end

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Store.Supervisor]
    Supervisor.start_link(children ++ redix_workers, opts)
  end
end

defmodule Store.Redix do
  def command(command) do
    Redix.command(:"redix_#{random_index()}", command)
  end

  defp random_index() do
    rem(System.unique_integer([:positive]), 5)
  end
end
