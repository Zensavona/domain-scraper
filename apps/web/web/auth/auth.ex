defmodule Web.Auth do
  import Comeonin.Bcrypt, only: [checkpw: 2, dummy_checkpw: 0]
  alias Web.User
  alias Web.Repo

  def login(conn, user) do
    conn
    |> Guardian.Plug.sign_in(user)
  end

  def login_by_email_and_pass(conn, email, given_pass) do
    if !is_nil(email) && !is_nil(given_pass) do
      user = Repo.get_by(User, email: email)
      cond do
        user && checkpw(given_pass, user.password_hash) ->
          {:ok, login(conn, user)}
        user ->
          {:error, :unauthorized, conn}
        true ->
          dummy_checkpw
          {:error, :not_found, conn}
      end
    else
      {:error, :unauthorized, conn}
    end
  end

  def logout(conn) do
    Guardian.Plug.sign_out(conn)
  end
end
