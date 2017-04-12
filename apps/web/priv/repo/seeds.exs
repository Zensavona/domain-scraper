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

zen = User.registration_changeset(%User{}, %{email: "z@zen.id.au", first_name: "Zen", last_name: "Savona", password: "tex19932008"})
Repo.insert!(zen)

kevin = User.registration_changeset(%User{}, %{email: "kevin@kevingraham.com", first_name: "Kevin", last_name: "Graham", password: "kevkevkev"})
Repo.insert!(kevin)

jesse = User.registration_changeset(%User{}, %{email: "jesse@jessehanley.com", first_name: "Jesse", last_name: "Hanley", password: "jessejesse"})
Repo.insert!(jesse)
