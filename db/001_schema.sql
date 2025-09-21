-- (facoltativo, di solito è già attivo su Supabase)
create extension if not exists pgcrypto;

-- Nota: public.profiles estende auth.users; crea un record con lo stesso id
-- quando Supabase aggiunge un utente nella tabella auth.users.
-- ========== PROFILES ==========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text,
  role text not null default 'employee' check (role in ('boss','employee')),
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

-- ========== AVAILABILITIES (sera 19–23, on/off per giorno) ==========
create table if not exists public.availabilities (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,
  created_at timestamptz default now(),
  unique (rider_id, day)
);

alter table public.availabilities enable row level security;
