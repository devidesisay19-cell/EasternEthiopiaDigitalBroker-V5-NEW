-- =====================================================================
-- EEDB V5 - BASE SCHEMA, PART 2 of 2: RLS policies + contact RPCs
-- Run AFTER SUPABASE_FINAL_V4.sql (uses eedb_is_super_admin,
-- eedb_is_listing_admin, eedb_can_manage_city, eedb_owns_property,
-- eedb_admin_can_manage_property). Safe to re-run.
-- =====================================================================

-- ---- wipe old policies on the tables this file manages ----
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
           where schemaname='public'
             and tablename in ('locations','properties','property_images','jobs',
                               'job_applications','job_saved','job_notifications')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.locations         enable row level security;
alter table public.properties        enable row level security;
alter table public.property_images   enable row level security;
alter table public.jobs              enable row level security;
alter table public.job_applications  enable row level security;
alter table public.job_saved         enable row level security;
alter table public.job_notifications enable row level security;

-- ---------- locations ----------
create policy locations_read on public.locations
  for select using (is_active or public.eedb_is_super_admin());
create policy locations_super_write on public.locations
  for all using (public.eedb_is_super_admin()) with check (public.eedb_is_super_admin());

-- ---------- properties ----------
create policy properties_public_read on public.properties
  for select using (status = 'published');
create policy properties_owner_read on public.properties
  for select to authenticated using (owner_id = auth.uid());
create policy properties_admin_read on public.properties
  for select to authenticated
  using (public.eedb_is_listing_admin() and public.eedb_can_manage_city(city_id));
create policy properties_owner_insert on public.properties
  for insert to authenticated with check (owner_id = auth.uid());
create policy properties_owner_update on public.properties
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy properties_admin_update on public.properties
  for update to authenticated
  using (public.eedb_is_listing_admin() and public.eedb_can_manage_city(city_id))
  with check (public.eedb_is_listing_admin() and public.eedb_can_manage_city(city_id));
create policy properties_owner_delete on public.properties
  for delete to authenticated using (owner_id = auth.uid());
create policy properties_super_delete on public.properties
  for delete to authenticated using (public.eedb_is_super_admin());

-- Non-admins: new posts start as pending_review, cannot change owner,
-- cannot self-publish, cannot self-feature (featured = paid by admin).
create or replace function public.eedb_lock_property()
returns trigger language plpgsql as $$
begin
  if auth.uid() is null or public.eedb_is_listing_admin() then return new; end if;
  if tg_op = 'INSERT' then
    new.status := 'pending_review';
    new.is_featured := false;
    new.featured_until := null;
    new.reviewed_by := null; new.reviewed_at := null; new.rejection_reason := null;
    return new;
  end if;
  if new.owner_id is distinct from old.owner_id then
    raise exception 'owner_id cannot be changed';
  end if;
  new.is_featured := old.is_featured;
  new.featured_until := old.featured_until;
  if new.status is distinct from old.status
     and new.status not in ('pending_review','hidden','sold','rented') then
    raise exception 'Only an admin can set status to %', new.status;
  end if;
  return new;
end $$;
drop trigger if exists properties_lock on public.properties;
create trigger properties_lock before insert or update on public.properties
for each row execute function public.eedb_lock_property();

-- ---------- property_images ----------
create policy property_images_read on public.property_images
  for select using (
    exists (select 1 from public.properties p where p.id = property_id and p.status = 'published')
    or public.eedb_owns_property(property_id)
    or public.eedb_admin_can_manage_property(property_id));
create policy property_images_owner_write on public.property_images
  for insert to authenticated with check (public.eedb_owns_property(property_id));
create policy property_images_admin_write on public.property_images
  for insert to authenticated with check (public.eedb_admin_can_manage_property(property_id));
create policy property_images_owner_update on public.property_images
  for update to authenticated using (public.eedb_owns_property(property_id))
  with check (public.eedb_owns_property(property_id));
create policy property_images_owner_delete on public.property_images
  for delete to authenticated using (public.eedb_owns_property(property_id));
create policy property_images_admin_delete on public.property_images
  for delete to authenticated using (public.eedb_admin_can_manage_property(property_id));

-- ---------- jobs ----------
create policy jobs_public_read on public.jobs
  for select using (status = 'published');
create policy jobs_employer_read on public.jobs
  for select to authenticated using (employer_id = auth.uid() or posted_by = auth.uid());
create policy jobs_admin_read on public.jobs
  for select to authenticated
  using (public.eedb_is_listing_admin() and public.eedb_can_manage_city(city_id));
create policy jobs_employer_insert on public.jobs
  for insert to authenticated with check (employer_id = auth.uid() and posted_by = auth.uid());
create policy jobs_admin_insert on public.jobs
  for insert to authenticated
  with check (public.eedb_is_listing_admin() and public.eedb_can_manage_city(city_id));
create policy jobs_employer_update on public.jobs
  for update to authenticated using (employer_id = auth.uid()) with check (employer_id = auth.uid());
create policy jobs_admin_update on public.jobs
  for update to authenticated
  using (public.eedb_is_listing_admin() and public.eedb_can_manage_city(city_id))
  with check (public.eedb_is_listing_admin() and public.eedb_can_manage_city(city_id));
create policy jobs_employer_delete on public.jobs
  for delete to authenticated using (employer_id = auth.uid());
create policy jobs_super_delete on public.jobs
  for delete to authenticated using (public.eedb_is_super_admin());

create or replace function public.eedb_lock_job()
returns trigger language plpgsql as $$
begin
  if auth.uid() is null or public.eedb_is_listing_admin() then return new; end if;
  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.posting_method := 'employer';
    new.reviewed_by := null; new.reviewed_at := null; new.rejection_reason := null;
    return new;
  end if;
  if new.employer_id is distinct from old.employer_id then
    raise exception 'employer_id cannot be changed';
  end if;
  if new.status is distinct from old.status and new.status not in ('pending','closed') then
    raise exception 'Only an admin can set status to %', new.status;
  end if;
  return new;
end $$;
drop trigger if exists jobs_lock on public.jobs;
create trigger jobs_lock before insert or update on public.jobs
for each row execute function public.eedb_lock_job();

-- ---------- job_applications ----------
create policy job_apps_applicant_read on public.job_applications
  for select to authenticated using (applicant_id = auth.uid());
create policy job_apps_employer_read on public.job_applications
  for select to authenticated
  using (exists (select 1 from public.jobs j where j.id = job_id and j.employer_id = auth.uid()));
create policy job_apps_admin_read on public.job_applications
  for select to authenticated
  using (public.eedb_is_listing_admin() and exists (
    select 1 from public.jobs j where j.id = job_id and public.eedb_can_manage_city(j.city_id)));
create policy job_apps_applicant_insert on public.job_applications
  for insert to authenticated
  with check (applicant_id = auth.uid()
              and exists (select 1 from public.jobs j where j.id = job_id and j.status = 'published'));
create policy job_apps_applicant_update on public.job_applications
  for update to authenticated using (applicant_id = auth.uid())
  with check (applicant_id = auth.uid() and status in ('pending','withdrawn'));
create policy job_apps_employer_update on public.job_applications
  for update to authenticated
  using (exists (select 1 from public.jobs j where j.id = job_id and j.employer_id = auth.uid()))
  with check (exists (select 1 from public.jobs j where j.id = job_id and j.employer_id = auth.uid()));

-- ---------- job_saved / job_notifications ----------
create policy job_saved_own on public.job_saved
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy job_notif_read on public.job_notifications
  for select to authenticated using (user_id = auth.uid());
create policy job_notif_update on public.job_notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- contact RPCs (city admins + super admins of a city, owner contact) ----------
create or replace function public.get_property_contacts(p_city_id uuid)
returns table(id uuid, full_name text, phone text, role text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.phone, p.role
    from public.profiles p
   where coalesce(p.is_active, true)
     and (p.role = 'super_admin'
          or (p.role in ('city_admin','admin') and exists (
                select 1 from public.admin_city_assignments a
                 where a.admin_id = p.id and a.city_id = p_city_id)))
$$;

create or replace function public.get_listing_contacts(p_city_id uuid)
returns table(id uuid, full_name text, phone text, role text)
language sql stable security definer set search_path = public as $$
  select * from public.get_property_contacts(p_city_id)
$$;

-- only returns the owner's contact if they have a published property
create or replace function public.get_property_owner_contact(p_owner_id uuid)
returns table(id uuid, full_name text, phone text, role text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.phone, p.role
    from public.profiles p
   where p.id = p_owner_id
     and exists (select 1 from public.properties x
                  where x.owner_id = p_owner_id and x.status = 'published')
$$;

grant execute on function public.get_property_contacts(uuid) to anon, authenticated;
grant execute on function public.get_listing_contacts(uuid) to anon, authenticated;
grant execute on function public.get_property_owner_contact(uuid) to anon, authenticated;
