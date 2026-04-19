-- Run this once in your Supabase project SQL editor.
--
-- Creates the `profiles` table (if it doesn't already exist) with the
-- columns the premium app needs. If `profiles` already exists from
-- another Rewoven app's migration, the alter statement just adds any
-- missing columns — nothing is dropped or overwritten.

-- 1. Create profiles table linked to Supabase auth users.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  created_at timestamptz not null default now(),
  is_premium boolean not null default false,
  stripe_customer_id text,
  stripe_subscription_id text,
  subscription_status text,
  premium_until timestamptz
);

-- 2. Make sure premium columns exist (in case profiles was already there
--    from another migration without these fields).
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

-- 3. Auto-create a profile row whenever a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. Backfill profiles for any users who already exist in auth.users
--    but don't have a profile row yet.
insert into public.profiles (id, email)
select id, email from auth.users
on conflict (id) do nothing;

-- 5. Row-level security: users can read their own profile.
--    (The premium app uses the service-role key, which bypasses RLS, so
--    writes from the Stripe webhook always succeed regardless of policies.)
alter table public.profiles enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies
                 where tablename = 'profiles' and policyname = 'profiles_self_read') then
    create policy profiles_self_read on public.profiles
      for select using (auth.uid() = id);
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies
                 where tablename = 'profiles' and policyname = 'profiles_self_update') then
    create policy profiles_self_update on public.profiles
      for update using (auth.uid() = id);
  end if;
end $$;
