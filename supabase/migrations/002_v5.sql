-- FURI Mining Algeria v5 additions
create table if not exists public.deposit_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  network text not null default 'BSC',
  asset text not null default 'USDT',
  amount numeric(30,8) not null check (amount > 0),
  tx_hash text not null,
  status text not null default 'pending' check (status in ('pending','confirmed','rejected')),
  confirmed_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists deposit_requests_tx_hash_uq on public.deposit_requests(tx_hash);
create index if not exists deposit_requests_user_id_idx on public.deposit_requests(user_id);
create index if not exists deposit_requests_status_idx on public.deposit_requests(status);

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  network text not null default 'BSC',
  asset text not null default 'USDT',
  amount numeric(30,8) not null check (amount > 0),
  destination_address text not null,
  status text not null default 'pending' check (status in ('pending','approved','processing','paid','rejected')),
  tx_hash text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);
create index if not exists withdrawal_requests_user_id_idx on public.withdrawal_requests(user_id);
create index if not exists withdrawal_requests_status_idx on public.withdrawal_requests(status);

alter table public.deposit_requests enable row level security;
alter table public.withdrawal_requests enable row level security;
revoke all on public.deposit_requests from anon, authenticated;
revoke all on public.withdrawal_requests from anon, authenticated;
grant select, insert on public.deposit_requests to authenticated;
grant select, insert on public.withdrawal_requests to authenticated;

drop policy if exists "deposit own select" on public.deposit_requests;
create policy "deposit own select" on public.deposit_requests for select to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists "deposit own insert" on public.deposit_requests;
create policy "deposit own insert" on public.deposit_requests for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "withdraw own select" on public.withdrawal_requests;
create policy "withdraw own select" on public.withdrawal_requests for select to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists "withdraw own insert" on public.withdrawal_requests;
create policy "withdraw own insert" on public.withdrawal_requests for insert to authenticated with check (user_id = auth.uid());

alter table public.user_plans add column if not exists amount_usdt numeric(30,8);
update public.user_plans up set amount_usdt=p.price_usdt from public.plans p where p.id=up.plan_id and up.amount_usdt is null;
alter table public.furi_ledger add column if not exists description text;
update public.furi_ledger set description=coalesce(note,entry_type) where description is null;

drop policy if exists "admin_roles_own_read" on public.admin_roles;
create policy "admin_roles_own_read" on public.admin_roles for select to authenticated using (user_id = auth.uid());

