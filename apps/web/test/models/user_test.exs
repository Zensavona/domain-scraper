defmodule Web.UserTest do
  use Web.ModelCase

  alias Web.User

  @valid_attrs %{email: "some content", first_name: "some content", is_admin: true, last_name: "some content", password_hash: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end
end
