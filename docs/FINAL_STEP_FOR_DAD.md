# 👨 Final step — for Dad

The premium subscription site is built, deployed, and running on the
Contabo VPS. **Everything is ready to launch except the Lemon Squeezy
account**, which has to be in your name (because you're the one with the
PayPal + ID).

This is a **15-minute job**, end to end.

---

## What you're doing

You're signing up for a service called **Lemon Squeezy** — they're a
"merchant of record". That means *they* legally collect the payment
from customers, handle taxes, and pay you (via PayPal). Rewoven doesn't
need to be a registered business because Lemon Squeezy is. You just
need an individual account.

Then you copy 4 values from Lemon Squeezy → into a config file on the
VPS → restart the service. Done.

---

## Step 1 — Create the Lemon Squeezy account

1. Go to **https://lemonsqueezy.com** → click **Start for free**.
2. Sign up with your email + a password.
3. When asked, fill in:
   - **Country**: where you live
   - **Personal name**: your full legal name
   - **Phone number**: your number
4. **Add PayPal for payouts**: Settings → Payouts → connect your PayPal.
   *(Or bank account if you prefer.)*

✅ You're now an LS creator. Total time: ~5 min.

---

## Step 2 — Create the Rewoven store

1. From the Lemon Squeezy dashboard → **Stores** (left sidebar) →
   **+ New store**.
2. Fill in:
   - **Store name**: `Rewoven`
   - **Store URL slug**: `rewoven` (so checkout will be at
     `rewoven.lemonsqueezy.com`)
   - **Currency**: USD
3. Save.
4. After save, copy the **Store ID** (a number, shown on the store
   detail page) — write it down.

---

## Step 3 — Create the subscription product

1. **Products** (left sidebar) → **+ New product**.
2. Fill in:
   - **Name**: `Rewoven Premium`
   - **Description**: `Unlocks the Rewoven Curriculum, unlimited fabric
     scans, and the multiplayer quiz at quiz.rewovenapp.com.`
   - **Status**: Published
3. **Pricing**:
   - **Type**: Subscription
   - **Price**: `4.99 USD`
   - **Billing interval**: Monthly
4. Save the product.
5. After save, click into the product → **Variants** tab → copy the
   **Variant ID** (a number) — write it down.

---

## Step 4 — Create the API key

1. Go to **Settings → API** → **+ Create API key**.
2. Name it `Rewoven Premium VPS`.
3. Copy the **bearer token** (a long string starting with something like
   `eyJ...`) — you'll see it ONCE, write it down immediately.

---

## Step 5 — Create the webhook

1. **Settings → Webhooks** → **+ Create webhook**.
2. Fill in:
   - **Callback URL**: `https://premium.rewovenapp.com/webhooks/lemonsqueezy`
   - **Signing secret**: type a random password (e.g. open Terminal and
     run `openssl rand -hex 32`, or just mash some letters and numbers
     for 32 characters). **Write down what you typed.**
   - **Events** (tick these 5):
     - [x] subscription_created
     - [x] subscription_updated
     - [x] subscription_resumed
     - [x] subscription_cancelled
     - [x] subscription_expired
3. Save.

---

## Step 6 — Plug the values into the VPS

You should now have **4 values** written down:
- LEMONSQUEEZY_API_KEY (from step 4)
- LEMONSQUEEZY_STORE_ID (from step 2)
- LEMONSQUEEZY_VARIANT_ID (from step 3)
- LEMONSQUEEZY_WEBHOOK_SECRET (from step 5 — the one *you typed*)

SSH into the VPS:

```
ssh root@185.197.250.205
```

Open the env file:

```
nano /opt/rewoven_premium/.env.prod
```

Find these 4 lines and replace `placeholder` with the real values:

```
LEMONSQUEEZY_API_KEY=...
LEMONSQUEEZY_STORE_ID=...
LEMONSQUEEZY_VARIANT_ID=...
LEMONSQUEEZY_WEBHOOK_SECRET=...
```

Save (Ctrl-O, Enter, Ctrl-X) and restart the service:

```
systemctl restart rewoven-premium
systemctl status rewoven-premium
```

You should see "active (running)".

---

## Step 7 — Test it

1. Open `https://premium.rewovenapp.com`.
2. Click "Sign in to subscribe" (sign in with Google).
3. Click **Subscribe — $4.99/mo**.
4. You should land on a Lemon Squeezy checkout page.
5. **In test mode**, use card `4242 4242 4242 4242`, any future expiry,
   any CVC, any postal code.
6. After payment → redirected back to `/success`.
7. In the Supabase dashboard → SQL editor → run:
   ```sql
   select email, is_premium from public.profiles
   where email = 'YOUR_EMAIL';
   ```
   You should see `is_premium = true` within ~5 seconds.

If yes → you're done. The premium subscription is live.

---

## What to do if something breaks

```
ssh root@185.197.250.205
journalctl -u rewoven-premium -n 100
```

Common issues:

| Symptom | Cause | Fix |
|---|---|---|
| 502 Bad Gateway | App not running | `systemctl restart rewoven-premium` |
| Subscribe button does nothing | LS API key wrong | Check `.env.prod`, restart |
| Payment goes through but `is_premium` stays false | Webhook secret mismatch | Re-copy the secret you typed in LS, replace in `.env.prod`, restart |
| Webhook 400 error | Same as above | Same |

---

## Switching to live mode

Lemon Squeezy starts in **test mode**. To take real payments:

1. LS dashboard → top-right toggle → switch to "Live mode"
2. Repeat steps 3–5 (create product, API key, webhook) — these are
   separate between test and live mode
3. Update `.env.prod` with the new live values
4. `systemctl restart rewoven-premium`

That's it.
