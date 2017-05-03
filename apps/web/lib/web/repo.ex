defmodule Web.Repo do
  use Ecto.Repo, otp_app: :web

  @migrations_dir Path.join([:code.priv_dir(:your_application), "repo", "migrations"])

  def migrate do
    Ecto.Migrator.run(__MODULE__, @migrations_dir, :up, [all: true])
  end
end
