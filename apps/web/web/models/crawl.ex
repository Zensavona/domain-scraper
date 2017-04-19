defmodule Web.Crawl do
  use Web.Web, :model

  schema "crawls" do
    field :seed, :string
    field :urls, :integer
    field :finished_at, Ecto.DateTime
    field :began_at, Ecto.DateTime
    field :is_queued, :boolean

    belongs_to :user, Web.User
    belongs_to :crawl_set, Web.CrawlSet
    has_many :domains, Web.Domain

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:seed, :finished_at, :began_at, :urls, :is_queued])
    |> validate_required([:seed, :began_at])
    |> cast_assoc(:user)
  end

  def all_for_user_without_crawl_set_members(user) do
     from c in Web.Crawl, where: is_nil(c.crawl_set_id) and c.user_id == ^user.id
  end

  def by_id_for_user(user, crawl_id) do
    from c in Web.Crawl, where: c.id == ^crawl_id and c.user_id == ^user.id
  end
end
