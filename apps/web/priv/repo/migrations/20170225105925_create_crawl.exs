defmodule Web.Repo.Migrations.CreateCrawl do
  use Ecto.Migration

  def change do
    create table(:crawls) do
      add :seed, :string
      add :urls, :integer, null: false, default: 0
      add :finished_at, :utc_datetime
      add :began_at, :utc_datetime, null: false

      timestamps()
    end

  end
end
