defmodule Web.CrawlSet do
  use Web.Web, :model

  schema "crawl_sets" do
    field :phrase, :string
    field :finished_at, Ecto.DateTime
    field :began_at, Ecto.DateTime

    belongs_to :user, Web.User
    has_many :crawls, Web.Crawl

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:phrase, :began_at, :finished_at])
    |> validate_required([:phrase, :began_at])
    |> cast_assoc(:crawls)
  end
end
