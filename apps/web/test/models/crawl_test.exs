defmodule Web.CrawlTest do
  use Web.ModelCase

  alias Web.Crawl

  @valid_attrs %{began_at: %{day: 17, hour: 14, min: 0, month: 4, sec: 0, year: 2010}, finished_at: %{day: 17, hour: 14, min: 0, month: 4, sec: 0, year: 2010}, seed: "some content", urls: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Crawl.changeset(%Crawl{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Crawl.changeset(%Crawl{}, @invalid_attrs)
    refute changeset.valid?
  end
end
