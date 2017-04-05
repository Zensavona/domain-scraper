defmodule Web.Crawl do
  use Web.Web, :model

  schema "crawls" do
    field :seed, :string
    field :urls, :integer
    field :finished_at, Ecto.DateTime
    field :began_at, Ecto.DateTime
    has_many :domains, Web.Domain

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:seed, :finished_at, :began_at, :urls])
    |> validate_required([:seed, :began_at])
  end
end
