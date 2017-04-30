# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Web.Repo.insert!(%Web.SomeModel{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Web.Repo
alias Web.User

zen = User.registration_changeset(%User{}, %{email: "z@zen.id.au", first_name: "Zen", last_name: "Savona", password: "zenzenzen"})
case Repo.get_by(User, email: zen.changes.email) do
  nil ->
    Repo.insert(zen)
  _ ->
    :user_exists
end

kevin = User.registration_changeset(%User{}, %{email: "kevin@kevingraham.com", first_name: "Kevin", last_name: "Graham", password: "kevkevkev"})
case Repo.get_by(User, email: kevin.changes.email) do
  nil ->
    Repo.insert(kevin)
  _ ->
    :user_exists
end

jesse = User.registration_changeset(%User{}, %{email: "jesse@jessehanley.com", first_name: "Jesse", last_name: "Hanley", password: "jessejesse"})
case Repo.get_by(User, email: jesse.changes.email) do
  nil ->
    Repo.insert(jesse)
  _ ->
    :user_exists
end

matt = User.registration_changeset(%User{}, %{email: "matt", first_name: "Matt", last_name: "Eaton", password: "mattmattmatt"})
case Repo.get_by(User, email: matt.changes.email) do
  nil ->
    Repo.insert(matt)
  _ ->
    :user_exists
end

jason = User.registration_changeset(%User{}, %{email: "jason@the.domain.name", first_name: "Jason", last_name: "Duke", password: "Jason@JasonD"})
case Repo.get_by(User, email: jason.changes.email) do
  nil ->
    Repo.insert(jason)
  _ ->
    :user_exists
end
