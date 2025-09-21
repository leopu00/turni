-- (facoltativo, di solito è già attivo su Supabase)
create extension if not exists pgcrypto;

-- Nota: public.profiles estende auth.users; crea un record con lo stesso id
-- quando Supabase aggiunge un utente nella tabella auth.users.
-- ========== PROFILES ==========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text,
  display_name text,
  role text not null default 'employee' check (role in ('boss','employee')),
  created_at timestamptz default now()
);

-- Garantisce la presenza della colonna display_name anche su tabelle già esistenti.
alter table public.profiles
  add column if not exists display_name text;

-- Assicura che username/display_name siano valorizzati automaticamente.
-- Rimuove eventuali trigger precedenti che dipendono dalla vecchia funzione.
drop trigger if exists profiles_set_defaults on public.profiles;
drop trigger if exists profiles_set_username on public.profiles;
-- Rimuove la vecchia funzione usata dai trigger precedenti.
drop function if exists public.set_profile_username();

-- Crea la funzione che calibra username e display_name per i record di profiles.
create or replace function public.set_profile_defaults()
returns trigger as $$
begin
  if new.email is not null and (new.username is null or btrim(new.username) = '') then
    new.username := split_part(new.email, '@', 1);
  end if;
  if (new.display_name is null or btrim(new.display_name) = '') then
    select coalesce(
             nullif(to_jsonb(u)->>'display_name', ''),
             nullif(u.raw_user_meta_data->>'full_name', ''),
             nullif(u.raw_user_meta_data->>'name', '')
           )
    into new.display_name
    from auth.users u
    where u.id = new.id;
    if new.display_name is null or btrim(new.display_name) = '' then
      new.display_name := coalesce(new.username, split_part(new.email, '@', 1));
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

-- Collega la funzione al ciclo di vita dei record della tabella profiles.
create trigger profiles_set_defaults
before insert or update on public.profiles
for each row
execute function public.set_profile_defaults();

-- Backfill per eventuali record esistenti senza username.
update public.profiles
set username = split_part(email, '@', 1)
where email is not null
  and (username is null or btrim(username) = '');

-- Backfill display_name dai dati auth.users (fallback su username/email).
update public.profiles p
set display_name = coalesce(
      nullif(to_jsonb(u)->>'display_name', ''),
      nullif(u.raw_user_meta_data->>'full_name', ''),
      nullif(u.raw_user_meta_data->>'name', ''),
      split_part(p.email, '@', 1)
    )
from auth.users u
where p.id = u.id
  and (p.display_name is null or btrim(p.display_name) = '');

-- Abilita RLS subito dopo aver definito struttura e trigger.
alter table public.profiles enable row level security;

-- ========== AVAILABILITIES (sera 19–23, on/off per giorno) ==========
-- Crea la tabella per le disponibilità giornaliere dei rider.
create table if not exists public.availabilities (
  id uuid primary key default gen_random_uuid(),
  rider_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,
  created_at timestamptz default now(),
  unique (rider_id, day)
);

-- Abilita RLS sulle disponibilità.
alter table public.availabilities enable row level security;
