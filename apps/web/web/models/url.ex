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
    |> cast(params, [:url, :crawl_id])
    |> validate_required([:url])
    |> unique_constraint(:url, name: :unique_crawl_id_url_combination)
  end
end
