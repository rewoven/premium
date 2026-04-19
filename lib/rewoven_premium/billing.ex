defmodule RewovenPremium.Billing do
  @moduledoc """
  Stripe checkout + webhook helpers.

  Required env vars:
    STRIPE_SECRET_KEY     sk_live_... or sk_test_...
    STRIPE_PUBLIC_KEY     pk_live_... or pk_test_... (only used in templates)
    STRIPE_PRICE_ID       price_... for the $4.99/mo Rewoven Premium product
    STRIPE_WEBHOOK_SECRET whsec_... for verifying webhook signatures
    PREMIUM_BASE_URL      e.g. https://premium.rewovenapp.com
  """

  alias RewovenPremium.Supabase

  @doc """
  Create a Stripe Checkout Session for the signed-in user.

  Returns `{:ok, %{url: stripe_url}}` — redirect the user there.
  """
  def create_checkout_session(user_id, user_email) do
    base = Application.fetch_env!(:rewoven_premium, :premium_base_url)
    price_id = Application.fetch_env!(:rewoven_premium, :stripe_price_id)

    Stripe.Checkout.Session.create(%{
      mode: "subscription",
      payment_method_types: ["card"],
      customer_email: user_email,
      line_items: [%{price: price_id, quantity: 1}],
      client_reference_id: user_id,
      metadata: %{"supabase_user_id" => user_id},
      subscription_data: %{metadata: %{"supabase_user_id" => user_id}},
      success_url: base <> "/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: base <> "/"
    })
  end

  @doc """
  Create a Stripe customer-portal session so an existing subscriber can
  manage / cancel their subscription.
  """
  def create_portal_session(stripe_customer_id) do
    base = Application.fetch_env!(:rewoven_premium, :premium_base_url)

    Stripe.BillingPortal.Session.create(%{
      customer: stripe_customer_id,
      return_url: base <> "/account"
    })
  end

  @doc """
  Verify a Stripe webhook signature and return the parsed event.
  """
  def construct_webhook_event(payload, signature) do
    secret = Application.fetch_env!(:rewoven_premium, :stripe_webhook_secret)
    Stripe.Webhook.construct_event(payload, signature, secret)
  end

  @doc """
  Handle a verified Stripe webhook event by mirroring subscription state
  back into Supabase.
  """
  def handle_event(%Stripe.Event{type: "checkout.session.completed", data: %{object: session}}) do
    user_id = session.client_reference_id || get_in(session.metadata, ["supabase_user_id"])
    if user_id do
      Supabase.update_premium(user_id, %{
        is_premium: true,
        stripe_customer_id: session.customer,
        stripe_subscription_id: session.subscription,
        subscription_status: "active"
      })
    end
    :ok
  end

  def handle_event(%Stripe.Event{type: type, data: %{object: sub}})
      when type in ["customer.subscription.updated", "customer.subscription.created"] do
    user_id = get_in(sub.metadata, ["supabase_user_id"])
    if user_id do
      Supabase.update_premium(user_id, %{
        is_premium: sub.status in ["active", "trialing"],
        stripe_subscription_id: sub.id,
        subscription_status: sub.status,
        premium_until: format_period_end(sub.current_period_end)
      })
    end
    :ok
  end

  def handle_event(%Stripe.Event{type: "customer.subscription.deleted", data: %{object: sub}}) do
    user_id = get_in(sub.metadata, ["supabase_user_id"])
    if user_id do
      Supabase.update_premium(user_id, %{
        is_premium: false,
        subscription_status: "canceled"
      })
    end
    :ok
  end

  def handle_event(_), do: :ok

  defp format_period_end(nil), do: nil
  defp format_period_end(unix) when is_integer(unix) do
    DateTime.from_unix!(unix) |> DateTime.to_iso8601()
  end
end
