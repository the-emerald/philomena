defmodule PhilomenaWeb.EnsureRegistrationEnabledPlug do
  import Phoenix.Controller
  import Plug.Conn

  def init([]), do: false

  def call(conn, _opts) do
    if Application.get_env(:philomena, :registration_enabled, true) do
      conn
    else
      conn
      |> put_flash(:error, "Registrations are closed.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
