defmodule RewovenPremium.Billing do
  @moduledoc """
  Lemon Squeezy checkout + webhook helpers.

  Required env vars:
    LEMONSQUEEZY_API_KEY        Bearer token from Settings → API
    LEMONSQUEEZY_STORE_ID       Numeric store ID
    LEMONSQUEEZY_VARIANT_ID     Numeric variant ID for the $4.99/mo subscription
    LEMONSQUEEZY_WEBHOOK_SECRET Signing secret you set when creating the webhook
    PREMIUM_BASE_URL            e.g. https://premium.rewovenapp.com

  Lemon Squeezy is the merchant of record — you don't need a registered
  business; Lemon Squeezy handles tax + payment legally and pays you out
  via PayPal.
  """

  require Logger
  alias RewovenPremium.Supabase

  @api "https://api.lemonsqueezy.com/v1"

  # ---------------------------------------------------------------------------
  # Checkout
  # ---------------------------------------------------------------------------

  @doc """
  Create a Lemon Squeezy checkout session for the signed-in user.

  Returns `{:ok, %{url: checkout_url}}` — redirect the user there.
  We tag the checkout with the user's Supabase ID via `custom_data` so
  the webhook can map the resulting subscription back to the right row.
  """
  def create_checkout_session(user_id, user_email) do
    base = Application.fetch_env!(:rewoven_premium, :premium_base_url)
    store_id = Application.fetch_env!(:rewoven_premium, :lemonsqueezy_store_id)
    variant_id = Application.fetch_env!(:rewoven_premium, :lemonsqueezy_variant_id)

    body = %{
      "data" => %{
        "type" => "checkouts",
        "attributes" => %{
          "checkout_data" => %{
            "email" => user_email,
            "custom" => %{"supabase_user_id" => user_id}
          },
          "checkout_options" => %{
            "embed" => false,
            "media" => false,
            "logo" => true
          },
          "product_options" => %{
            "redirect_url" => base <> "/success",
            "receipt_button_text" => "Back to Rewoven",
            "receipt_link_url" => base <> "/account",
            "enabled_variants" => [String.to_integer(variant_id)]
          }
        },
        "relationships" => %{
          "store" => %{"data" => %{"type" => "stores", "id" => to_string(store_id)}},
          "variant" => %{"data" => %{"type" => "variants", "id" => to_string(variant_id)}}
        }
      }
    }

    case Req.post(@api <> "/checkouts", headers: api_headers(), json: body) do
      {:ok, %{status: 201, body: %{"data" => %{"attributes" => %{"url" => url}}}}} ->
        {:ok, %{url: url}}

      {:ok, %{status: status, body: b}} ->
        Logger.error("Lemon Squeezy checkout failed: #{status} #{inspect(b)}")
        {:error, {status, b}}

      err ->
        err
    end
  end

  @doc """
  Build the customer-portal URL for an existing subscriber so they can
  cancel / update payment. We get the URL from the subscription attrs we
  stored in Supabase.
  """
  def get_portal_url(subscription_id) when is_binary(subscription_id) do
    case Req.get(@api <> "/subscriptions/" <> subscription_id, headers: api_headers()) do
      {:ok, %{status: 200, body: %{"data" => %{"attributes" => %{"urls" => %{"customer_portal" => url}}}}}} ->
        {:ok, %{url: url}}

      err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Webhook signature verification
  # ---------------------------------------------------------------------------

  @doc """
  Verify a Lemon Squeezy webhook signature against the raw request body.
  Lemon Squeezy uses HMAC-SHA256(secret, raw_body), hex-encoded.
  """
  def verify_signature(raw_body, signature_header) do
    secret = Application.fetch_env!(:rewoven_premium, :lemonsqueezy_webhook_secret)

    expected =
      :crypto.mac(:hmac, :sha256, secret, raw_body)
      |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(expected, signature_header || "") do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  # ---------------------------------------------------------------------------
  # Webhook event handling
  # ---------------------------------------------------------------------------

  @doc """
  Mirror a verified webhook event into Supabase.
  Lemon Squeezy events we care about:
    subscription_created, subscription_updated, subscription_resumed
    subscription_cancelled, subscription_expired
  """
  def handle_event(%{"meta" => meta, "data" => data}) do
    event_name = meta["event_name"]
    user_id = get_in(meta, ["custom_data", "supabase_user_id"])
    attrs = data["attributes"] || %{}
    sub_id = data["id"]

    if user_id do
      premium? = event_name in ~w(subscription_created subscription_updated subscription_resumed) and
                 attrs["status"] in ~w(active on_trial paused)

      Supabase.update_premium(user_id, %{
        is_premium: premium?,
        stripe_customer_id: to_string(attrs["customer_id"] || ""),
        stripe_subscription_id: to_string(sub_id),
        subscription_status: attrs["status"],
        premium_until: attrs["renews_at"]
      })
    else
      Logger.warning("Lemon Squeezy webhook with no supabase_user_id: #{event_name}")
    end

    :ok
  end

  def handle_event(_), do: :ok

  # ---------------------------------------------------------------------------

  defp api_headers do
    [
      {"accept", "application/vnd.api+json"},
      {"content-type", "application/vnd.api+json"},
      {"authorization", "Bearer " <> Application.fetch_env!(:rewoven_premium, :lemonsqueezy_api_key)}
    ]
  end
end
