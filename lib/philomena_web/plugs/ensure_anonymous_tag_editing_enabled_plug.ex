defmodule PhilomenaWeb.EnsureAnonymousTagEditingEnabledPlug do
  import Phoenix.Controller
  import Plug.Conn

  def init([]), do: false

  def call(conn, _opts) do
    if Application.get_env(:philomena, :anonymous_tag_editing_enabled, true) ||
         conn.assigns.current_user do
      conn
    else
      conn
      |> put_flash(:error, "You must be signed in to edit tags.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
