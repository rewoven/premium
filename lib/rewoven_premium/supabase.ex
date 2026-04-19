defmodule RewovenPremium.Supabase do
  @moduledoc """
  Thin wrapper around the Supabase REST API for reading & updating user
  profiles. Uses the service-role key so it can bypass row-level security
  for premium-status writes (Stripe webhooks).

  Required env vars (set at runtime):
    SUPABASE_URL          e.g. https://xxxxx.supabase.co
    SUPABASE_SERVICE_KEY  service_role key (KEEP SECRET — server-only)
    SUPABASE_ANON_KEY     anon/public key (used for verifying user JWTs)
  """

  defp base_url, do: Application.fetch_env!(:rewoven_premium, :supabase_url)
  defp service_key, do: Application.fetch_env!(:rewoven_premium, :supabase_service_key)
  defp anon_key, do: Application.fetch_env!(:rewoven_premium, :supabase_anon_key)

  @doc "Verify a Supabase user JWT and return the user object."
  def verify_jwt(jwt) when is_binary(jwt) do
    Req.get(base_url() <> "/auth/v1/user",
      headers: [
        {"apikey", anon_key()},
        {"authorization", "Bearer " <> jwt}
      ]
    )
    |> case do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: s, body: b}} -> {:error, {s, b}}
      err -> err
    end
  end

  @doc "Fetch a user's premium-related profile fields."
  def get_profile(user_id) do
    Req.get(base_url() <> "/rest/v1/profiles",
      headers: service_headers(),
      params: [
        select: "id,is_premium,stripe_customer_id,stripe_subscription_id,subscription_status,premium_until",
        id: "eq." <> user_id
      ]
    )
    |> case do
      {:ok, %{status: 200, body: [profile | _]}} -> {:ok, profile}
      {:ok, %{status: 200, body: []}} -> {:error, :not_found}
      err -> err
    end
  end

  @doc "Upsert premium fields on a profile (called from Stripe webhook handlers)."
  def update_premium(user_id, attrs) when is_map(attrs) do
    Req.patch(base_url() <> "/rest/v1/profiles",
      headers: service_headers() ++ [{"prefer", "return=representation"}],
      params: [id: "eq." <> user_id],
      json: attrs
    )
    |> case do
      {:ok, %{status: s, body: b}} when s in 200..299 -> {:ok, b}
      err -> err
    end
  end

  defp service_headers do
    [
      {"apikey", service_key()},
      {"authorization", "Bearer " <> service_key()},
      {"content-type", "application/json"}
    ]
  end
end
