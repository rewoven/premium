defmodule RewovenPremiumWeb.WebhookController do
  use RewovenPremiumWeb, :controller

  alias RewovenPremium.Billing

  @doc """
  Lemon Squeezy webhook endpoint. The raw body is captured by
  RawBodyReader before Plug.Parsers consumes it, so we can recompute the
  HMAC-SHA256 signature and compare it to the X-Signature header.
  """
  def lemonsqueezy(conn, params) do
    raw_body = conn.assigns[:raw_body] || ""
    signature = get_req_header(conn, "x-signature") |> List.first() || ""

    case Billing.verify_signature(raw_body, signature) do
      :ok ->
        Billing.handle_event(params)
        send_resp(conn, 200, "ok")

      {:error, reason} ->
        send_resp(conn, 400, "invalid signature: #{inspect(reason)}")
    end
  rescue
    e -> send_resp(conn, 400, "error: #{Exception.message(e)}")
  end
end
