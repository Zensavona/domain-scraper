use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :web, Web.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :web, Web.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "",
  hostname: "163.172.191.107",
  database: "web_prod",
  pool_size: 20
