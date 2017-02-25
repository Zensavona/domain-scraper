defmodule Web.Crawl do
  use Web.Web, :model

  schema "crawls" do
    field :seed, :string
    field :urls, :integer
    field :finished_at, Ecto.DateTime
    field :began_at, Ecto.DateTime
    has_many :domain, Web.Domain

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:seed, :urls, :finished_at, :began_at])
    |> validate_required([:seed, :urls, :finished_at, :began_at])
  end
end
