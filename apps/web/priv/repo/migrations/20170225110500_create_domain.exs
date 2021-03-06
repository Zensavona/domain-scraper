defmodule Web.Repo.Migrations.CreateDomain do
  use Ecto.Migration

  def change do
    create table(:domains) do
      add :domain, :string
      add :status, :boolean, default: false, null: false
      add :crawl_id, references(:crawls, on_delete: :nothing)

      timestamps()
    end
    create index(:domains, [:crawl_id])
    create unique_index(:domains, [:crawl_id, :domain], name: :unique_crawl_id_domain_combination)

  end
end
