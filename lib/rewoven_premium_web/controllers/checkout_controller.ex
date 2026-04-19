defmodule RewovenPremiumWeb.CheckoutController do
  use RewovenPremiumWeb, :controller

  alias RewovenPremium.{Billing, Supabase}

  @doc """
  Receives the user's Supabase JWT (passed in the Authorization header by
  the front-end), verifies it, and creates a Stripe Checkout Session.
  Responds with JSON `{url: "https://checkout.stripe.com/..."}` so the
  front-end can `window.location = url`.
  """
  def create(conn, _params) do
    with {:ok, jwt} <- bearer_token(conn),
         {:ok, user} <- Supabase.verify_jwt(jwt),
         {:ok, session} <- Billing.create_checkout_session(user["id"], user["email"]) do
      json(conn, %{url: session.url})
    else
      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: inspect(reason)})
    end
  end

  @doc """
  Open the Stripe Customer Portal for an existing subscriber so they can
  update payment method or cancel.
  """
  def portal(conn, _params) do
    with {:ok, jwt} <- bearer_token(conn),
         {:ok, user} <- Supabase.verify_jwt(jwt),
         {:ok, profile} <- Supabase.get_profile(user["id"]),
         customer_id when is_binary(customer_id) <- profile["stripe_customer_id"],
         {:ok, session} <- Billing.create_portal_session(customer_id) do
      json(conn, %{url: session.url})
    else
      _ -> conn |> put_status(400) |> json(%{error: "no_subscription"})
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      ["bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end
end
