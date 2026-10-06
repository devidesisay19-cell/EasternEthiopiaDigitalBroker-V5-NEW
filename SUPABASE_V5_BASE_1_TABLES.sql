-- =====================================================================
-- EEDB V5 - BASE SCHEMA, PART 1 of 2: tables, indexes, triggers, RPCs
-- Written from the app code (no dump of the old project was available).
-- (Contact RPCs live in part 2 because they need admin_city_assignments from V4.)
-- Run order on a NEW Supabase project:
--   1) SUPABASE_V5_BASE_1_TABLES.sql   (this file)
--   2) SUPABASE_FINAL_V4.sql
--   3) SUPABASE_V5_BASE_2_POLICIES.sql
--   4) SUPABASE_V5_BROKERS.sql
-- Safe to re-run.
-- =====================================================================
create extension if not exists pgcrypto;

-- ---------- profiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  role text not null default 'renter',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------- locations (region > zone > city > woreda > area) ----------
create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.locations(id) on delete cascade,
  name text not null,
  type text not null check (type in ('region','zone','city','woreda','area')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists locations_type_idx on public.locations(type, is_active);
create index if not exists locations_parent_idx on public.locations(parent_id);

-- ---------- properties ----------
create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  listing_type text not null default 'rent',        -- rent | sell
  price numeric(14,2) not null default 0,
  location text,
  bedrooms int,
  bathrooms int,
  area_size text,
  description text,
  status text not null default 'pending_review',    -- pending_review|published|rejected|hidden|sold|rented
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  is_featured boolean not null default false,
  featured_until timestamptz,
  region_id uuid, zone_id uuid, city_id uuid, woreda_id uuid, area_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists properties_status_idx on public.properties(status, created_at desc);
create index if not exists properties_city_idx on public.properties(city_id);
create index if not exists properties_owner_idx on public.properties(owner_id);

create table if not exists public.property_images (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties(id) on delete cascade,
  storage_path text not null,
  display_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists property_images_prop_idx on public.property_images(property_id, display_order);

-- ---------- jobs ----------
create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid references auth.users(id) on delete cascade,
  posted_by uuid references auth.users(id) on delete set null,
  posting_method text not null default 'employer',  -- employer | admin
  title text not null,
  description text,
  category text,
  job_type text,
  salary numeric(14,2),
  company_name text,
  contact_phone text,
  contact_email text,
  application_deadline date,
  status text not null default 'pending',           -- pending|published|rejected|closed
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  region_id uuid, zone_id uuid, city_id uuid, woreda_id uuid, area_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists jobs_status_idx on public.jobs(status, created_at desc);
create index if not exists jobs_city_idx on public.jobs(city_id);
create index if not exists jobs_employer_idx on public.jobs(employer_id);

create table if not exists public.job_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  applicant_id uuid not null references auth.users(id) on delete cascade,
  cover_message text,
  cv_url text,
  status text not null default 'pending',   -- pending|reviewing|shortlisted|accepted|rejected|withdrawn
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists job_apps_job_idx on public.job_applications(job_id);
create index if not exists job_apps_applicant_idx on public.job_applications(applicant_id);

create table if not exists public.job_saved (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (job_id, user_id)
);

create table if not exists public.job_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  message text,
  job_id uuid references public.jobs(id) on delete cascade,
  application_id uuid references public.job_applications(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists job_notif_user_idx on public.job_notifications(user_id, created_at desc);

-- ---------- triggers ----------
-- keep updated_at fresh
create or replace function public.eedb_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

drop trigger if exists properties_touch on public.properties;
create trigger properties_touch before update on public.properties
for each row execute function public.eedb_touch_updated_at();
drop trigger if exists jobs_touch on public.jobs;
create trigger jobs_touch before update on public.jobs
for each row execute function public.eedb_touch_updated_at();

-- max 5 photos per property (server-side)
create or replace function public.eedb_limit_property_images()
returns trigger language plpgsql as $$
begin
  if (select count(*) from public.property_images where property_id = new.property_id) >= 5 then
    raise exception 'Maximum 5 photos per property';
  end if;
  return new;
end $$;
drop trigger if exists property_images_limit on public.property_images;
create trigger property_images_limit before insert on public.property_images
for each row execute function public.eedb_limit_property_images();

-- notify the applicant when the employer changes the application status
create or replace function public.eedb_notify_application()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status and new.status <> 'withdrawn' then
    insert into public.job_notifications(user_id, title, message, job_id, application_id)
    values (new.applicant_id, 'Application update',
            'Your application status is now: ' || new.status, new.job_id, new.id);
  end if;
  return new;
end $$;
drop trigger if exists job_applications_notify on public.job_applications;
create trigger job_applications_notify after update on public.job_applications
for each row execute function public.eedb_notify_application();
