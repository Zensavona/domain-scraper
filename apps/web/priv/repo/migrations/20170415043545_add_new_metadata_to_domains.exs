defmodule Web.Repo.Migrations.AddNewMetadataToDomains do
  use Ecto.Migration

  def change do
    alter table(:domains) do
      add :tf, :float
      add :cf, :float
      add :da, :float
      add :pa, :float
      add :mozrank, :float
      add :a_cnt, :float
      add :a_cnt_r, :float
      add :a_links, :float
      add :a_rank, :integer
      add :el, :float
      add :equity, :float
      add :links, :integer
      add :refd, :float
      add :spam, :float
      add :sr_costs, :float
      add :sr_dlinks, :integer
      add :sr_hlinks, :integer
      add :sr_kwords, :integer
      add :sr_rank, :float
      add :sr_traffic, :float
      add :sr_ulinks, :integer
    end
  end
end
