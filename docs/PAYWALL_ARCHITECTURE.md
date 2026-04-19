# Paywall architecture

Single source of truth: **`profiles.is_premium` in Supabase**. Every Rewoven
app reads from this same field. There is no per-app database, no
duplicated subscription state, no syncing problem.

```
                    ┌─────────────────────────┐
                    │     Lemon Squeezy        │
                    │   (merchant of record)   │
                    └──────────┬──────────────┘
                               │  webhook on
                               │  subscribe / cancel
                               ▼
            ┌────────────────────────────────────────┐
            │   premium.rewovenapp.com (this app)     │
            │   /webhooks/lemonsqueezy                │
            │     - verifies signature                │
            │     - looks up supabase_user_id         │
            │     - writes is_premium = true/false    │
            └──────────┬─────────────────────────────┘
                       │  service_role key
                       ▼
            ┌────────────────────────────────────────┐
            │             Supabase                    │
            │       profiles                          │
            │       ├── id (= auth.users.id)          │
            │       ├── email                         │
            │       ├── is_premium    ◄── source      │
            │       ├── stripe_subscription_id        │
            │       │     (we reuse this column for   │
            │       │      LS subscription id)        │
            │       ├── subscription_status           │
            │       └── premium_until                 │
            └──────────┬─────────────────────────────┘
                       │
        ┌──────────────┼──────────────┬─────────────────┐
        │              │              │                 │
        ▼              ▼              ▼                 ▼
  ┌──────────┐  ┌────────────┐  ┌────────────┐  ┌──────────────┐
  │  Mobile  │  │   Quiz     │  │ Curriculum │  │  Anything    │
  │   app    │  │ (Phoenix)  │  │  (future)  │  │  else        │
  │ scan tab │  │ /host      │  │            │  │              │
  └──────────┘  └────────────┘  └────────────┘  └──────────────┘

  Each app reads `profiles.is_premium` for the signed-in user
  and gates its own premium features locally.
```

---

## How each app gates its features

### 1. Mobile app — scanner (5 free / month, unlimited premium)

`services/premium.ts` (per `docs/SCANNER_PAYWALL.md`):

```ts
const { data: profile } = await supabase
  .from('profiles')
  .select('is_premium')
  .eq('id', userId)
  .maybeSingle();

if (profile?.is_premium) return { ok: true, remaining: null };

// else: count fabric_scans created this month, block at 5
```

The check happens **before** the camera fires. Non-premium users hit
the 5-scan ceiling and see an `Alert.alert` with a "Get Premium" button
linking to `https://premium.rewovenapp.com`.

### 2. Quiz — `/host` page (creating games is premium-only)

Already implemented in `rewoven/quiz` `live/host_live.ex`. Client-side
JS check on page load:

```js
const { data: { user } } = await sb.auth.getUser();
const { data: profile } = await sb
  .from('profiles')
  .select('is_premium')
  .eq('id', user.id)
  .maybeSingle();

if (profile?.is_premium) revealHostForm();
else lockBehindPaywall();
```

Players joining with a code don't need premium, so a single premium
host can run the quiz for a whole class.

### 3. Curriculum (future, `curriculum.rewovenapp.com`)

Planned: separate Phoenix LiveView app. Server-side gate via a plug:

```elixir
defmodule CurriculumWeb.Plugs.RequirePremium do
  alias RewovenPremium.Supabase

  def init(opts), do: opts

  def call(conn, _opts) do
    with token when is_binary(token) <- get_supabase_jwt(conn),
         {:ok, user} <- Supabase.verify_jwt(token),
         {:ok, %{"is_premium" => true}} <- Supabase.get_profile(user["id"]) do
      assign(conn, :current_user, user)
    else
      _ -> conn |> redirect(external: "https://premium.rewovenapp.com") |> halt()
    end
  end
end
```

Server-side gates are stronger than client-side — the curriculum
content never even ships to the browser if the user isn't premium.

### 4. premium.rewovenapp.com itself

This app shows different UI based on `is_premium`:
- **Anonymous** → "Sign in to subscribe"
- **Signed in, not premium** → "Subscribe — $4.99/mo"
- **Premium** → "Manage subscription" (opens Lemon Squeezy customer portal)

See `lib/rewoven_premium_web/controllers/page_html/home.html.heex`.

---

## Security model

Two key questions:

### Q: Can a user just edit `is_premium = true` in their own row?

**No.** Row-level security policies (in `priv/supabase_migration.sql`):

```sql
create policy profiles_self_read on profiles
  for select using (auth.uid() = id);

create policy profiles_self_update on profiles
  for update using (auth.uid() = id);
```

The `update` policy lets users update *their own* row in general — but
we don't expose `is_premium` writes from the client. The only writes
to `is_premium` come from the **Lemon Squeezy webhook**, using the
**service_role key**, which bypasses RLS.

For extra safety you can add a column-level grant restriction so even
authenticated users can't write `is_premium`:

```sql
revoke update (is_premium, stripe_customer_id, stripe_subscription_id,
               subscription_status, premium_until)
  on public.profiles from authenticated;
```

### Q: What if someone bypasses the client-side check?

Client-side gates (mobile scanner, quiz host) are easily bypassed with
DevTools or a patched APK. For the **curriculum** and other high-value
content we use server-side gates (Phoenix plug above) — content never
leaves the server unless the user is genuinely premium.

For now, client-side gates are **good enough** for $4.99/mo casual
users. Tighten later if abuse becomes a real problem (it usually
doesn't at this price point).

---

## Why this design

- **One field, one source of truth.** No "where's the subscription state"
  questions later.
- **Apps are decoupled.** Curriculum, quiz, mobile, marketing site can
  each ship updates independently. Premium logic is one Supabase query.
- **No vendor lock-in to Lemon Squeezy.** If we switch providers (back
  to Stripe, to Paddle, etc.), only this premium app changes. Other
  apps don't notice.
- **Easy to manually grant premium** for testing, refunds, comp accounts:
  just `update profiles set is_premium = true where email = '...';` in
  the Supabase SQL editor.
