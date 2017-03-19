defmodule Web.Url do
  use Web.Web, :model

  schema "urls" do
    field :url, :string
    field :response_code, :boolean, default: false
    belongs_to :crawl, Web.Crawl

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:url, :response_code])
    |> validate_required([:url, :response_code])
  end
end
