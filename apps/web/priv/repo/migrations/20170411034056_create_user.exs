defmodule Web.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :password_hash, :string, null: false
      add :is_admin, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
