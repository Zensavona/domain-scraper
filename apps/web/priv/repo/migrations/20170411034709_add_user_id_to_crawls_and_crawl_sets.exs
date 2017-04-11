defmodule Web.Repo.Migrations.AddUserIdToCrawlsAndCrawlSets do
  use Ecto.Migration

  def change do
    alter table(:crawls) do
      add :user_id, references(:users, on_delete: :nothing)
    end

    alter table(:crawl_sets) do
      add :user_id, references(:users, on_delete: :nothing)
    end

    create index(:crawls, [:user_id])
    create index(:crawl_sets, [:user_id])
  end
end
