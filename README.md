# Rewoven Premium

Subscription site for premium.rewovenapp.com. Phoenix app that lets
signed-in Rewoven users subscribe to **Rewoven Premium ($4.99/mo)** through
Stripe Checkout. Premium status is mirrored to Supabase so the mobile app,
the curriculum site, and quiz.rewovenapp.com can read it.

## What it does

1. User clicks "Subscribe" on the homepage.
2. They sign in with Supabase (same Google/Apple OAuth as the mobile app).
3. They're redirected to Stripe Checkout.
4. After payment, Stripe webhooks `checkout.session.completed` and
   `customer.subscription.*` flip `is_premium = true` on the user's row in
   the Supabase `profiles` table.
5. The mobile app, curriculum, and quiz read `is_premium` and unlock.

## Setup

### 1. Supabase
Run `priv/supabase_migration.sql` in the Supabase SQL editor. It adds the
columns the premium app needs.

### 2. Stripe
- Create a product called **Rewoven Premium** with a recurring **$4.99/mo**
  price. Copy the price ID (`price_xxx`).
- In *Developers → Webhooks*, add an endpoint pointing at
  `https://premium.rewovenapp.com/webhooks/stripe`. Subscribe to:
    - `checkout.session.completed`
    - `customer.subscription.created`
    - `customer.subscription.updated`
    - `customer.subscription.deleted`
  Copy the signing secret (`whsec_xxx`).
- Grab your secret key (`sk_live_xxx`) and publishable key (`pk_live_xxx`).

### 3. Environment variables
Put these in your VPS environment (systemd unit, Docker env, etc.):

```
SECRET_KEY_BASE=<mix phx.gen.secret>
PHX_HOST=premium.rewovenapp.com
PHX_SERVER=true
PORT=4000

SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<anon key>
SUPABASE_SERVICE_KEY=<service_role key — keep secret>

STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_PUBLIC_KEY=pk_live_xxx
STRIPE_PRICE_ID=price_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx

PREMIUM_BASE_URL=https://premium.rewovenapp.com
```

### 4. Deploy

Build a release on the server:

```bash
mix deps.get --only prod
MIX_ENV=prod mix release
_build/prod/rel/rewoven_premium/bin/rewoven_premium start
```

Or run dev mode to test locally:

```bash
mix setup
mix phx.server
# open http://localhost:4000
```

Put it behind nginx/Caddy with TLS pointing at port 4000.

### 5. DNS
Point `premium.rewovenapp.com` at your VPS.

## How other apps check premium

Every Rewoven app reads the same field from Supabase:

```ts
const { data: profile } = await supabase
  .from('profiles')
  .select('is_premium, subscription_status, premium_until')
  .eq('id', user.id)
  .single();

if (profile?.is_premium) {
  // unlock premium features
}
```

## File map

```
lib/rewoven_premium/
  billing.ex           Stripe checkout + webhook event handlers
  supabase.ex          Supabase REST client (verify JWT, read/write profiles)

lib/rewoven_premium_web/
  router.ex            Routes: /, /account, /success, /checkout, /portal, /webhooks/stripe
  endpoint.ex          Plug pipeline (uses RawBodyReader for webhook signature)
  raw_body_reader.ex   Captures raw body for /webhooks/stripe
  controllers/
    page_controller.ex      / /account /success
    checkout_controller.ex  POST /checkout, /portal (returns Stripe URL)
    webhook_controller.ex   POST /webhooks/stripe
  components/
    layouts.ex              Shared <.premium_page> chrome + Supabase JS bootstrap
```
