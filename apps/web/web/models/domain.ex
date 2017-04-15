defmodule Web.Domain do
  use Web.Web, :model

  schema "domains" do
    field :domain, :string
    field :status, :boolean, default: false
    field :tf, :float
    field :cf, :float
    field :da, :float
    field :pa, :float
    field :mozrank, :float
    field :a_cnt, :float
    field :a_cnt_r, :float
    field :a_links, :float
    field :a_rank, :integer
    field :el, :float
    field :equity, :float
    field :links, :integer
    field :refd, :float
    field :spam, :float
    field :sr_costs, :float
    field :sr_dlinks, :integer
    field :sr_hlinks, :integer
    field :sr_kwords, :integer
    field :sr_rank, :float
    field :sr_traffic, :float
    field :sr_ulinks, :integer


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
end
