defmodule RewovenPremiumWeb.PageController do
  use RewovenPremiumWeb, :controller

  alias RewovenPremium.Supabase

  @doc "Landing page — features, pricing, subscribe / manage button."
  def home(conn, _params) do
    {user, profile} = current_user_and_profile(conn)
    render(conn, :home, user: user, profile: profile,
      supabase_url: cfg(:supabase_url),
      supabase_anon_key: cfg(:supabase_anon_key))
  end

  @doc "Account page — only meaningful for signed-in users with a sub."
  def account(conn, _params) do
    {user, profile} = current_user_and_profile(conn)
    render(conn, :account, user: user, profile: profile,
      supabase_url: cfg(:supabase_url),
      supabase_anon_key: cfg(:supabase_anon_key))
  end

  @doc "Stripe redirects here after a successful checkout."
  def success(conn, _params) do
    {user, profile} = current_user_and_profile(conn)
    render(conn, :success, user: user, profile: profile,
      supabase_url: cfg(:supabase_url),
      supabase_anon_key: cfg(:supabase_anon_key))
  end

  # --- Helpers ---

  defp current_user_and_profile(conn) do
    case get_jwt(conn) do
      nil -> {nil, nil}
      jwt ->
        case Supabase.verify_jwt(jwt) do
          {:ok, user} ->
            profile = case Supabase.get_profile(user["id"]) do
              {:ok, p} -> p
              _ -> nil
            end
            {user, profile}
          _ -> {nil, nil}
        end
    end
  end

  defp get_jwt(conn) do
    # Supabase JS SDK stores the access token in a cookie named
    # "sb-<project-ref>-auth-token". The browser hands it to us; we just
    # forward it to Supabase to verify. Easier alternative: have the JS
    # send the token as a header on a fetch + server reads it. For the
    # initial server render we read the cookie directly.
    cookies = Plug.Conn.fetch_cookies(conn).req_cookies
    Enum.find_value(cookies, fn {name, val} ->
      cond do
        String.starts_with?(name, "sb-") and String.ends_with?(name, "-auth-token") ->
          extract_access_token(val)
        true -> nil
      end
    end)
  end

  # Supabase JS stores JSON like ["<access_token>","<refresh_token>",null,...]
  defp extract_access_token(val) do
    val =
      if String.starts_with?(val, "base64-") do
        case Base.decode64(String.trim_leading(val, "base64-"), padding: false) do
          {:ok, decoded} -> decoded
          _ -> val
        end
      else
        val
      end

    case Jason.decode(val) do
      {:ok, [token | _]} when is_binary(token) -> token
      {:ok, %{"access_token" => token}} -> token
      _ -> nil
    end
  end

  defp cfg(key), do: Application.get_env(:rewoven_premium, key)
end
