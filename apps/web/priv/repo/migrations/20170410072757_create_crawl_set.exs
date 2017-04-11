defmodule Web.Repo.Migrations.CreateCrawlSet do
  use Ecto.Migration

  def change do
    create table(:crawl_sets) do
      add :phrase, :string, null: false
      add :finished_at, :utc_datetime
      add :began_at, :utc_datetime, null: false

      timestamps()
    end

  end
end
