defmodule Web.Repo.Migrations.AddCrawlsetIdToCrawl do
  use Ecto.Migration

  def change do
    alter table(:crawls) do
      add :crawl_set_id, references(:crawl_sets, on_delete: :nothing)
    end
    create index(:crawls, [:crawl_set_id])
  end
end
