defmodule Web.Domain do
  use Web.Web, :model

  schema "domains" do
    field :domain, :string
    field :status, :boolean, default: false
    belongs_to :crawl, Web.Crawl

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:domain, :status, :crawl_id])
    |> validate_required([:domain, :status])
  end
end
