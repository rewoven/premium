# Rewoven Premium

Subscription site for **premium.rewovenapp.com**. Phoenix app that lets
signed-in Rewoven users subscribe to **Rewoven Premium ($4.99/mo)** via
**Lemon Squeezy** (merchant of record — handles payments + tax legally,
pays you out via PayPal). Premium status is mirrored to Supabase so the
mobile app, the curriculum site, and quiz.rewovenapp.com can read it.

## What it does

1. User clicks "Subscribe" on the homepage.
2. They sign in with Supabase (same Google/Apple OAuth as the mobile app).
3. They're redirected to a Lemon Squeezy hosted checkout page.
4. Lemon Squeezy webhooks `subscription_created` etc. flip
   `is_premium = true` on the user's row in the Supabase `profiles` table.
5. The mobile app, curriculum, and quiz read `is_premium` and unlock.

## Setup

### 1. Supabase
Run `priv/supabase_migration.sql` in the Supabase SQL editor.

### 2. Lemon Squeezy
1. Go to **lemonsqueezy.com** and sign up (with the PayPal account you'll
   receive payouts to).
2. Create a **Store** named "Rewoven".
3. **Products → New product** → "Rewoven Premium". Pricing model =
   **subscription**, $4.99 USD per month. Save. Click into the product →
   **Variants** tab → copy the **variant ID** (numeric).
4. **Settings → API** → **Create API key**. Copy the bearer token.
5. **Settings → Webhooks** → **+ Create webhook**:
   - URL: `https://premium.rewovenapp.com/webhooks/lemonsqueezy`
   - Events: `subscription_created`, `subscription_updated`,
     `subscription_resumed`, `subscription_cancelled`, `subscription_expired`
   - **Signing secret**: type a random string (e.g.
     `openssl rand -hex 32`). Save it — that's your webhook secret.
6. **Settings → Stores** → copy the numeric **Store ID**.

### 3. Environment variables

```
SECRET_KEY_BASE=<mix phx.gen.secret>
PHX_HOST=premium.rewovenapp.com
PHX_SERVER=true
PORT=4000

SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<anon key>
SUPABASE_SERVICE_KEY=<service_role key — keep secret>

LEMONSQUEEZY_API_KEY=<bearer token>
LEMONSQUEEZY_STORE_ID=<numeric>
LEMONSQUEEZY_VARIANT_ID=<numeric>
LEMONSQUEEZY_WEBHOOK_SECRET=<the random string you set>

PREMIUM_BASE_URL=https://premium.rewovenapp.com
```

### 4. Deploy

See `docs/DEPLOY.md` for a step-by-step VPS deployment using Caddy +
systemd.

### 5. Run locally for testing

```bash
mix setup
set -a && source .env && set +a
mix phx.server
# open http://localhost:4000
```

For local webhook testing, use `ngrok http 4000` and put the public
URL into your Lemon Squeezy webhook config.

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
  billing.ex           Lemon Squeezy checkout + webhook event handlers
  supabase.ex          Supabase REST client (verify JWT, read/write profiles)

lib/rewoven_premium_web/
  router.ex            Routes: /, /account, /success, /checkout, /portal,
                       /webhooks/lemonsqueezy
  endpoint.ex          Plug pipeline (uses RawBodyReader for webhook signature)
  raw_body_reader.ex   Captures raw body for /webhooks/lemonsqueezy
  controllers/
    page_controller.ex      / /account /success
    checkout_controller.ex  POST /checkout, /portal (returns LS URL)
    webhook_controller.ex   POST /webhooks/lemonsqueezy
  components/
    layouts.ex              Shared <.premium_page> chrome + Supabase JS bootstrap
```
