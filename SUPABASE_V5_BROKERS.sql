-- =====================================================================
-- EEDB V5: brokers (City Admin subscriptions). Run AFTER the base schema
-- and SUPABASE_FINAL_V4.sql. No limit on brokers per city.
-- =====================================================================

create table if not exists public.brokers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  city_id uuid not null,
  display_name text not null,
  phone text,
  whatsapp text,
  photo_url text,
  is_verified boolean not null default false,
  plan text not null default 'basic' check (plan in ('basic','pro')),
  status text not null default 'active' check (status in ('active','suspended')),
  active_until timestamptz not null default (now() + interval '30 days'),
  created_at timestamptz not null default now()
);
create index if not exists brokers_city_idx on public.brokers(city_id, status, active_until);

create table if not exists public.broker_payments (
  id uuid primary key default gen_random_uuid(),
  broker_id uuid not null references public.brokers(id) on delete cascade,
  amount numeric(12,2) not null,
  method text,                 -- telebirr / cbe / cash
  reference text,
  months int not null default 1,
  confirmed_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.brokers enable row level security;
alter table public.broker_payments enable row level security;

drop policy if exists brokers_public_read on public.brokers;
drop policy if exists brokers_super_all on public.brokers;
drop policy if exists brokers_self_update on public.brokers;
drop policy if exists broker_payments_read on public.broker_payments;
drop policy if exists broker_payments_super_all on public.broker_payments;

-- Everyone can read active, paid-up brokers (shown on Home).
create policy brokers_public_read on public.brokers
  for select using (status = 'active' and active_until >= now());

-- Only Super Admin adds / edits / suspends brokers and records payments.
create policy brokers_super_all on public.brokers
  for all using (public.eedb_is_super_admin())
  with check (public.eedb_is_super_admin());

-- A broker may read and edit contact details of their own row only.
create policy brokers_self_update on public.brokers
  for select using (user_id = auth.uid());

create policy broker_payments_read on public.broker_payments
  for select using (
    public.eedb_is_super_admin()
    or exists (select 1 from public.brokers b where b.id = broker_id and b.user_id = auth.uid()));
create policy broker_payments_super_all on public.broker_payments
  for all using (public.eedb_is_super_admin())
  with check (public.eedb_is_super_admin());

-- Super Admin: add a broker (makes the user a city_admin for that city).
create or replace function public.eedb_add_broker(
  p_user uuid, p_city uuid, p_name text, p_phone text, p_whatsapp text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.eedb_is_super_admin() then raise exception 'Only Super Admin'; end if;
  insert into public.brokers(user_id, city_id, display_name, phone, whatsapp)
  values (p_user, p_city, p_name, p_phone, coalesce(p_whatsapp, p_phone))
  on conflict (user_id) do update
    set city_id = excluded.city_id, display_name = excluded.display_name,
        phone = excluded.phone, whatsapp = excluded.whatsapp
  returning id into v_id;
  perform public.eedb_assign_city_admin(p_user, p_city);
  return v_id;
end $$;

-- Super Admin: confirm a monthly payment and extend the subscription.
create or replace function public.eedb_confirm_broker_payment(
  p_broker uuid, p_amount numeric, p_method text, p_reference text, p_months int default 1)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.eedb_is_super_admin() then raise exception 'Only Super Admin'; end if;
  insert into public.broker_payments(broker_id, amount, method, reference, months, confirmed_by)
  values (p_broker, p_amount, p_method, p_reference, p_months, auth.uid());
  update public.brokers
     set active_until = greatest(active_until, now()) + make_interval(months => p_months),
         status = 'active'
   where id = p_broker;
end $$;

grant execute on function public.eedb_add_broker(uuid,uuid,text,text,text) to authenticated;
grant execute on function public.eedb_confirm_broker_payment(uuid,numeric,text,text,int) to authenticated;
