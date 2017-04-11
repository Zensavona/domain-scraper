defmodule Web.CrawlSetTest do
  use Web.ModelCase

  alias Web.CrawlSet

  @valid_attrs %{phrase: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = CrawlSet.changeset(%CrawlSet{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = CrawlSet.changeset(%CrawlSet{}, @invalid_attrs)
    refute changeset.valid?
  end
end
