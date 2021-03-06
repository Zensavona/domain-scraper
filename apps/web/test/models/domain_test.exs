defmodule Web.DomainTest do
  use Web.ModelCase

  alias Web.Domain

  @valid_attrs %{domain: "some content", status: true}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Domain.changeset(%Domain{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Domain.changeset(%Domain{}, @invalid_attrs)
    refute changeset.valid?
  end
end
