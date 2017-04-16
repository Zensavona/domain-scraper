defmodule Web.Domain do
  use Web.Web, :model
  alias Web.Domain
  alias Web.Crawl

  schema "domains" do
    field :domain, :string
    field :status, :boolean, default: false
    field :tf, :string
    field :cf, :string
    field :da, :string
    field :pa, :string
    field :mozrank, :string
    field :a_cnt, :string
    field :a_cnt_r, :string
    field :a_links, :string
    field :a_rank, :string
    field :el, :string
    field :equity, :string
    field :links, :string
    field :refd, :string
    field :spam, :string
    field :sr_costs, :string
    field :sr_dlinks, :string
    field :sr_hlinks, :string
    field :sr_kwords, :string
    field :sr_rank, :string
    field :sr_traffic, :string
    field :sr_ulinks, :string


    belongs_to :crawl, Web.Crawl

    timestamps()
  end



  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params,  [:domain, :status, :crawl_id, :tf, :cf, :da, :pa, :mozrank, :a_cnt, :a_cnt_r, :a_links, :a_rank, :el, :equity, :links, :refd, :spam, :sr_costs, :sr_dlinks, :sr_hlinks, :sr_kwords, :sr_rank, :sr_traffic, :sr_ulinks])
    |> validate_required([:domain, :status])
    |> unique_constraint(:domain, name: :unique_crawl_id_domain_combination)
  end

  def by_id_for_user(user) do
    from d in Web.Domain, join: c in Crawl, where: c.user_id == ^user.id and d.status == true, order_by: [desc: [d.da, d.pa, d.tf, d.cf, d.mozrank]]
    # from d in Web.Domain, preload: [:crawl], where: d.crawl.user_id == ^user.id
  end
end
