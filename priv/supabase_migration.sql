-- Run this once in your Supabase project SQL editor.
-- It adds the columns the premium app needs on the existing `profiles` table.

alter table public.profiles
  add column if not exists is_premium boolean not null default false,
  add column if not exists stripe_customer_id text,
  add column if not exists stripe_subscription_id text,
  add column if not exists subscription_status text,
  add column if not exists premium_until timestamptz;

create index if not exists profiles_stripe_customer_idx
  on public.profiles (stripe_customer_id);

create index if not exists profiles_stripe_subscription_idx
  on public.profiles (stripe_subscription_id);

-- Row-level security: users can read their own premium fields.
-- (The premium app uses the service-role key, which bypasses RLS, so
-- writes always succeed regardless of these policies.)
alter table public.profiles enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname = 'profiles_self_read') then
    create policy profiles_self_read on public.profiles
      for select using (auth.uid() = id);
  end if;
end $$;
