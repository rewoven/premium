defmodule RewovenPremiumWeb.CheckoutController do
  use RewovenPremiumWeb, :controller

  alias RewovenPremium.{Billing, Supabase}

  @doc """
  Receives the user's Supabase JWT (Authorization header), verifies it,
  creates a Lemon Squeezy checkout, and returns `{url}` so the front-end
  can `window.location = url`.
  """
  def create(conn, _params) do
    with {:ok, jwt} <- bearer_token(conn),
         {:ok, user} <- Supabase.verify_jwt(jwt),
         {:ok, %{url: url}} <- Billing.create_checkout_session(user["id"], user["email"]) do
      json(conn, %{url: url})
    else
      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: inspect(reason)})

      other ->
        conn |> put_status(400) |> json(%{error: inspect(other)})
    end
  end

  @doc """
  Open the Lemon Squeezy customer portal so a subscriber can update
  payment / cancel.
  """
  def portal(conn, _params) do
    with {:ok, jwt} <- bearer_token(conn),
         {:ok, user} <- Supabase.verify_jwt(jwt),
         {:ok, profile} <- Supabase.get_profile(user["id"]),
         sub_id when is_binary(sub_id) and sub_id != "" <- profile["stripe_subscription_id"],
         {:ok, %{url: url}} <- Billing.get_portal_url(sub_id) do
      json(conn, %{url: url})
    else
      _ -> conn |> put_status(400) |> json(%{error: "no_subscription"})
    end
  end

  @doc """
  Returns the signed-in user's premium status. Used by /success to poll
  until the Lemon Squeezy webhook lands.
  """
  def me(conn, _params) do
    with {:ok, jwt} <- bearer_token(conn),
         {:ok, user} <- Supabase.verify_jwt(jwt),
         {:ok, profile} <- Supabase.get_profile(user["id"]) do
      json(conn, %{
        is_premium: !!profile["is_premium"],
        subscription_status: profile["subscription_status"],
        email: user["email"]
      })
    else
      _ -> conn |> put_status(401) |> json(%{is_premium: false})
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
