-- (facoltativo, di solito è già attivo su Supabase)
create extension if not exists pgcrypto;

-- ========== PROFILES ==========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text,
  role text not null default 'employee' check (role in ('boss','employee')),
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

-- Drop + Create per evitare errori se riesegui lo script
drop policy if exists "read own profile" on public.profiles;
create policy "read own profile"
on public.profiles
for select
to authenticated
using (id = (select auth.uid()));

drop policy if exists "upsert own profile" on public.profiles;
create policy "upsert own profile"
on public.profiles
for insert
to authenticated
with check (id = (select auth.uid()));

drop policy if exists "update own profile" on public.profiles;
create policy "update own profile"
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- ========== AVAILABILITIES (sera 19–23, on/off per giorno) ==========
create table if not exists public.availabilities (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,
  created_at timestamptz default now(),
  unique (rider_id, day)
);

alter table public.availabilities enable row level security;

-- employee: solo le proprie
drop policy if exists "employee read own" on public.availabilities;
create policy "employee read own"
on public.availabilities
for select
to authenticated
using (rider_id = (select auth.uid()));

drop policy if exists "employee insert own" on public.availabilities;
create policy "employee insert own"
on public.availabilities
for insert
to authenticated
with check (rider_id = (select auth.uid()));

drop policy if exists "employee update own" on public.availabilities;
create policy "employee update own"
on public.availabilities
for update
to authenticated
using (rider_id = (select auth.uid()))
with check (rider_id = (select auth.uid()));

drop policy if exists "employee delete own" on public.availabilities;
create policy "employee delete own"
on public.availabilities
for delete
to authenticated
using (rider_id = (select auth.uid()));

-- boss: può leggere tutto
drop policy if exists "boss can read all availabilities" on public.availabilities;
create policy "boss can read all availabilities"
on public.availabilities
for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'boss'
  )
);
