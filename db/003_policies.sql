-- ========== POLICIES: PROFILES ==========
-- Lettura libera agli utenti autenticati; write consentito solo sul proprio record.
drop policy if exists "profiles select all" on public.profiles;
create policy "profiles select all"
on public.profiles
for select
to authenticated
using (true);

drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own"
on public.profiles
for insert
to authenticated
with check (id = (select auth.uid()));

drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own"
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- ========== POLICIES: AVAILABILITIES ==========
-- Tutti possono leggere; ogni rider gestisce solo i propri slot.
drop policy if exists "availabilities select all" on public.availabilities;
create policy "availabilities select all"
on public.availabilities
for select
to authenticated
using (true);

drop policy if exists "availabilities insert own" on public.availabilities;
create policy "availabilities insert own"
on public.availabilities
for insert
to authenticated
with check (rider_id = (select auth.uid()));

drop policy if exists "availabilities update own" on public.availabilities;
create policy "availabilities update own"
on public.availabilities
for update
to authenticated
using (rider_id = (select auth.uid()))
with check (rider_id = (select auth.uid()));

drop policy if exists "availabilities delete own" on public.availabilities;
create policy "availabilities delete own"
on public.availabilities
for delete
to authenticated
using (rider_id = (select auth.uid()));
