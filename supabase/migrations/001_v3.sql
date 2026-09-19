-- FURI Mining v3
-- Auth + profiles + age calculation + admin authorization + RLS.
-- No crypto settlement is enabled by this migration.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (length(username) between 3 and 32),
  first_name text not null check (length(first_name) between 1 and 80),
  last_name text not null check (length(last_name) between 1 and 80),
  date_of_birth date not null,
  country_code char(2) not null default 'DZ' check (country_code='DZ'),
  status text not null default 'active' check (status in ('active','suspended','pending_review')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role in ('admin','support','finance_readonly')),
  created_at timestamptz not null default now()
);

create table if not exists public.plans (
  id text primary key,
  name text not null,
  price_usdt numeric(30,8) not null check(price_usdt >= 0),
  duration_days int not null check(duration_days > 0),
  furi_amount numeric(30,8) not null check(furi_amount >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.user_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_id text not null references public.plans(id),
  status text not null default 'selected',
  selected_at timestamptz not null default now(),
  expires_at timestamptz
);

create table if not exists public.furi_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(30,8) not null check(amount <> 0),
  entry_type text not null,
  reference_id uuid,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id),
  action text not null,
  entity text,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

insert into public.plans(id,name,price_usdt,duration_days,furi_amount) values
('day1','1 يوم',0.0001,1,10),
('day2','2 يوم',0.0002,2,25),
('day3','3 أيام',0.0003,3,40),
('premium','Premium',1,7,200)
on conflict(id) do update set
name=excluded.name,price_usdt=excluded.price_usdt,
duration_days=excluded.duration_days,furi_amount=excluded.furi_amount;

create or replace function public.calculate_age(dob date)
returns integer
language sql
stable
as $$ select extract(year from age(current_date, dob))::integer $$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1 from public.admin_roles
    where user_id = (select auth.uid())
      and role in ('admin','support','finance_readonly')
  )
$$;

revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

create or replace function public.admin_list_profiles()
returns table(
 id uuid, username text, first_name text, last_name text,
 date_of_birth date, age integer, country_code char(2),
 status text, created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id,p.username,p.first_name,p.last_name,p.date_of_birth,
         public.calculate_age(p.date_of_birth),p.country_code,p.status,p.created_at
  from public.profiles p
  where public.is_admin()
  order by p.created_at desc
$$;

revoke execute on function public.admin_list_profiles() from public, anon;
grant execute on function public.admin_list_profiles() to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  dob date;
  username_value text;
  first_name_value text;
  last_name_value text;
begin
  dob := (new.raw_user_meta_data->>'date_of_birth')::date;
  username_value := trim(new.raw_user_meta_data->>'username');
  first_name_value := trim(new.raw_user_meta_data->>'first_name');
  last_name_value := trim(new.raw_user_meta_data->>'last_name');

  if dob is null or public.calculate_age(dob) < 18 then
    raise exception 'Account requires age 18 or older';
  end if;

  if coalesce(new.raw_user_meta_data->>'country_code','DZ') <> 'DZ' then
    raise exception 'Only Algeria is enabled';
  end if;

  insert into public.profiles(id,username,first_name,last_name,date_of_birth,country_code)
  values(new.id,username_value,first_name_value,last_name_value,dob,'DZ');

  return new;
end
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.touch_updated_at()
returns trigger language plpgsql
set search_path=''
as $$ begin new.updated_at=now(); return new; end $$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute procedure public.touch_updated_at();

alter table public.profiles enable row level security;
alter table public.admin_roles enable row level security;
alter table public.plans enable row level security;
alter table public.user_plans enable row level security;
alter table public.furi_ledger enable row level security;
alter table public.audit_logs enable row level security;

revoke all on public.profiles, public.admin_roles, public.plans, public.user_plans,
  public.furi_ledger, public.audit_logs from anon, authenticated;

grant select, update on public.profiles to authenticated;
grant select on public.plans to authenticated;
grant select on public.user_plans to authenticated;
grant select on public.furi_ledger to authenticated;
grant select on public.audit_logs to authenticated;

create policy profiles_select_own on public.profiles
for select to authenticated using ((select auth.uid())=id);

create policy profiles_update_own on public.profiles
for update to authenticated
using ((select auth.uid())=id)
with check ((select auth.uid())=id and country_code='DZ');

create policy admin_profiles_select on public.profiles
for select to authenticated using ((select public.is_admin()));

create policy plans_read on public.plans
for select to authenticated using(active=true);

create policy user_plans_read_own on public.user_plans
for select to authenticated using((select auth.uid())=user_id);

create policy furi_read_own on public.furi_ledger
for select to authenticated using((select auth.uid())=user_id);

create policy audit_read_own on public.audit_logs
for select to authenticated using((select auth.uid())=user_id or (select public.is_admin()));

create index if not exists profiles_created_at_idx on public.profiles(created_at desc);
create index if not exists user_plans_user_id_idx on public.user_plans(user_id);
create index if not exists furi_ledger_user_id_idx on public.furi_ledger(user_id);
create index if not exists audit_logs_user_id_idx on public.audit_logs(user_id);

-- IMPORTANT:
-- Add the first admin manually after creating your own account:
-- insert into public.admin_roles(user_id,role) values ('YOUR-AUTH-USER-UUID','admin');
-- Do this only from the Supabase SQL Editor or another trusted admin channel.
