# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :web,
  ecto_repos: [Web.Repo]

# Configures the endpoint
config :web, Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "BuR2SZ+mDET9s7fPTucMnUFzaFHjeBw3tiuITHzR2NGSMqtTMvsblnmm8DVyM1aK",
  render_errors: [view: Web.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Web.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :hound, driver: "phantomjs"

config :guardian, Guardian,
  issuer: "Web.#{Mix.env}",
  ttl: {30, :days},
  verify_issuer: true,
  serializer: Web.GuardianSerializer,
  secret_key: to_string(Mix.env) <> "SuPerseCret_aBraCadabrA"

config :phoenix, :template_engines,
  slim: PhoenixSlime.Engine,
  slime: PhoenixSlime.Engine

import_config "scout_apm.exs"
config :web, Web.Repo,
  loggers: [{Ecto.LogEntry, :log, []},
            {ScoutApm.Instruments.EctoLogger, :log, []}]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
