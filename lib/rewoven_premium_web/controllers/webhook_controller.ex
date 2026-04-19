defmodule RewovenPremiumWeb.WebhookController do
  use RewovenPremiumWeb, :controller

  alias RewovenPremium.Billing

  @doc """
  Stripe webhook endpoint. The raw body is captured by RawBodyReader
  before Plug.Parsers consumes it. We re-verify it here using Stripe's
  webhook signature scheme.
  """
  def stripe(conn, _params) do
    raw_body = conn.assigns[:raw_body] || ""

    case get_req_header(conn, "stripe-signature") do
      [signature | _] ->
        case Billing.construct_webhook_event(raw_body, signature) do
          {:ok, event} ->
            Billing.handle_event(event)
            send_resp(conn, 200, "ok")

          {:error, reason} ->
            send_resp(conn, 400, "invalid signature: #{inspect(reason)}")
        end

      [] ->
        send_resp(conn, 400, "missing stripe-signature header")
    end
  rescue
    e -> send_resp(conn, 400, "error: #{Exception.message(e)}")
  end
end
