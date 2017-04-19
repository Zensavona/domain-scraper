defmodule Web.Repo.Migrations.AddIsQueuedToCrawls do
  use Ecto.Migration

  def change do
    alter table(:crawls) do
      add :is_queued, :boolean, default: false
    end
  end
end
