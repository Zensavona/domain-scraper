defmodule Web.Repo.Migrations.CreateUrl do
  use Ecto.Migration

  def change do
    create table(:urls) do
      add :url, :string
      add :response_code, :boolean, default: false, null: false
      add :crawl_id, references(:crawls, on_delete: :nothing)

      timestamps()
    end
    create index(:urls, [:crawl_id])
    create unique_index(:urls, [:crawl_id, :url], name: :unique_crawl_id_url_combination)

  end
end
