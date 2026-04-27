defmodule PhilomenaWeb.EnsureAnonymousReportsEnabledPlug do
  import Phoenix.Controller
  import Plug.Conn

  def init([]), do: false

  def call(conn, _opts) do
    if Application.get_env(:philomena, :anonymous_reports_enabled, true) ||
         conn.assigns.current_user do
      conn
    else
      conn
      |> put_flash(:error, "You must be signed in to submit reports.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
