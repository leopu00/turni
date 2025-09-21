-- Seed iniziale per negozi e associazioni profili/negozi
with frumento_shop as (
  insert into public.shops (name)
  values ('Frumento')
  on conflict (name) do update set name = excluded.name
  returning id
)
insert into public.profile_shops (profile_id, shop_id)
select p.id, frumento_shop.id
from public.profiles p
cross join frumento_shop
on conflict (profile_id, shop_id) do nothing;
