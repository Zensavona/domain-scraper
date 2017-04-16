defmodule Web.Repo.Migrations.AddNewMetadataToDomains do
  use Ecto.Migration

  def change do
    alter table(:domains) do
      add :tf, :float
      add :cf, :float
      add :da, :float
      add :pa, :float
      add :mozrank, :float
      add :a_cnt, :string
      add :a_cnt_r, :string
      add :a_links, :string
      add :a_rank, :string
      add :el, :string
      add :equity, :string
      add :links, :string
      add :refd, :string
      add :spam, :string
      add :sr_costs, :string
      add :sr_dlinks, :string
      add :sr_hlinks, :string
      add :sr_kwords, :string
      add :sr_rank, :string
      add :sr_traffic, :string
      add :sr_ulinks, :string
    end
  end
end
