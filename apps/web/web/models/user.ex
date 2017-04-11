defmodule Web.User do
  use Web.Web, :model

  schema "users" do
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :is_admin, :boolean, default: false

    has_many :crawls, Web.Crawl
    has_many :crawl_sets, Web.CrawlSet

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:email, :first_name, :last_name, :password_hash, :is_admin])
    |> validate_required([:email, :first_name, :last_name])
  end

  def registration_changeset(struct, params) do
    struct
    |> changeset(params)
    |> cast(params, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 100)
    |> hash_password
    |> IO.inspect
  end

  defp hash_password(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true,
                      changes: %{password: password}} ->
        put_change(changeset,
                   :password_hash,
                   Comeonin.Bcrypt.hashpwsalt(password))
      _ ->
        changeset
    end
  end
end
