defmodule RewovenPremiumWeb.RawBodyReader do
  @moduledoc """
  Custom body reader that stashes the raw request body on the conn for
  paths that need it (Stripe webhook signature verification).
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)

    conn =
      if conn.request_path == "/webhooks/lemonsqueezy" do
        Plug.Conn.assign(conn, :raw_body, body)
      else
        conn
      end

    {:ok, body, conn}
  end
end
