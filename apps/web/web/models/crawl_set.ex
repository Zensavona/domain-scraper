defmodule Web.CrawlSet do
  use Web.Web, :model

  schema "crawl_sets" do
    field :phrase, :string
    field :finished_at, Ecto.DateTime
    field :began_at, Ecto.DateTime

    has_many :crawls, Web.Crawl

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:phrase])
    |> validate_required([:phrase])
    |> cast_assoc(:crawls)
  end
end
