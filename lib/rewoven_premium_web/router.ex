defmodule RewovenPremiumWeb.Router do
  use RewovenPremiumWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RewovenPremiumWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :webhook do
    # Stripe webhooks need the raw body for signature verification, and
    # they don't need CSRF/session.
    plug :accepts, ["json"]
  end

  scope "/", RewovenPremiumWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/account", PageController, :account
    get "/success", PageController, :success

    post "/checkout", CheckoutController, :create
    post "/portal", CheckoutController, :portal
  end

  scope "/webhooks", RewovenPremiumWeb do
    pipe_through :webhook
    post "/stripe", WebhookController, :stripe
  end
end
