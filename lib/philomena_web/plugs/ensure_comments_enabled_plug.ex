defmodule PhilomenaWeb.EnsureCommentsEnabledPlug do
  import Phoenix.Controller
  import Plug.Conn

  def init([]), do: false

  def call(conn, _opts) do
    if Application.get_env(:philomena, :comments_enabled, true) do
      conn
    else
      conn
      |> put_flash(:error, "Comments are disabled.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
