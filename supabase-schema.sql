-- Edex Store: run this entire file in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function public.is_edex_admin()
returns boolean language sql stable security definer
set search_path = public
as $$ select exists (select 1 from public.admin_users where user_id = auth.uid()); $$;
revoke all on function public.is_edex_admin() from public;
grant execute on function public.is_edex_admin() to anon, authenticated;

create table if not exists public.store_prices (
  item_key text primary key,
  item_name text not null,
  category text not null check (category in ('zp','app')),
  price numeric(12,2) check (price is null or price >= 0),
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.store_prices(item_key,item_name,category,price) values
('zp_5k','5k + 2.5k bonus','zp',null),
('zp_10k','10k + 5k bonus','zp',null),
('zp_20k','20k + 10k bonus','zp',null),
('zp_50k','50k + 25k bonus','zp',null),
('app_capcut','CapCut','app',null),
('app_adobe','Adobe','app',null),
('app_canva','Canva','app',null),
('app_gemini','Gemini','app',null)
on conflict (item_key) do nothing;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null check (char_length(customer_name) between 1 and 120),
  customer_details text not null check (char_length(customer_details) between 1 and 2000),
  items jsonb not null,
  total numeric(12,2),
  status text not null default 'new' check (status in ('new','processing','completed','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_percent numeric(5,2) not null check (discount_percent > 0 and discount_percent <= 100),
  active boolean not null default true,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
alter table public.store_prices enable row level security;
alter table public.orders enable row level security;
alter table public.coupons enable row level security;

drop policy if exists "admins read own admin row" on public.admin_users;
create policy "admins read own admin row" on public.admin_users for select to authenticated using (user_id = auth.uid());

drop policy if exists "public read active prices" on public.store_prices;
create policy "public read active prices" on public.store_prices for select to anon, authenticated using (active = true or public.is_edex_admin());
drop policy if exists "admins manage prices" on public.store_prices;
create policy "admins manage prices" on public.store_prices for all to authenticated using (public.is_edex_admin()) with check (public.is_edex_admin());

drop policy if exists "customers create orders" on public.orders;
create policy "customers create orders" on public.orders for insert to anon, authenticated with check (true);
drop policy if exists "admins read orders" on public.orders;
create policy "admins read orders" on public.orders for select to authenticated using (public.is_edex_admin());
drop policy if exists "admins update orders" on public.orders;
create policy "admins update orders" on public.orders for update to authenticated using (public.is_edex_admin()) with check (public.is_edex_admin());

drop policy if exists "public read active coupons" on public.coupons;
create policy "public read active coupons" on public.coupons for select to anon, authenticated using (active = true and (expires_at is null or expires_at > now()));
drop policy if exists "admins manage coupons" on public.coupons;
create policy "admins manage coupons" on public.coupons for all to authenticated using (public.is_edex_admin()) with check (public.is_edex_admin());

 grant select on public.store_prices, public.coupons to anon, authenticated;
 grant insert on public.orders to anon, authenticated;
 grant select, update on public.orders to authenticated;
 grant select on public.admin_users to authenticated;
 grant insert, update, delete on public.store_prices, public.coupons to authenticated;
