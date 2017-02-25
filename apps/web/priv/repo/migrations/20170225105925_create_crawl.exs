defmodule Web.Repo.Migrations.CreateCrawl do
  use Ecto.Migration

  def change do
    create table(:crawls) do
      add :seed, :string
      add :urls, :integer
      add :finished_at, :utc_datetime
      add :began_at, :utc_datetime

      timestamps()
    end

  end
end
