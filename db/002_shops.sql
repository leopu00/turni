-- ========== SHOPS ==========
create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

-- ========== PROFILE_SHOPS (associazione molti-a-molti profili/negozi) ==========
create table if not exists public.profile_shops (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  primary key (profile_id, shop_id)
);
