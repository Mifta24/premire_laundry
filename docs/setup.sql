-- =============================================================================
-- PREMIER LAUNDRY — FULL DATABASE SETUP
-- Supabase PostgreSQL + RLS + Realtime
-- Jalankan di: Supabase SQL Editor (sekali jalan, top-to-bottom)
-- =============================================================================


-- =============================================================================
-- SECTION 1: EXTENSIONS
-- =============================================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";


-- =============================================================================
-- SECTION 2: TABLES
-- =============================================================================

-- -------------------------------------
-- 1. profiles
-- -------------------------------------
create table if not exists profiles (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  phone         text,
  role          text not null check (role in ('customer', 'courier', 'admin')),
  avatar_url    text,
  is_available  boolean not null default true,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  unique (user_id)
);

-- -------------------------------------
-- 2. addresses
-- -------------------------------------
create table if not exists addresses (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  label          text,
  address_text   text not null,
  latitude       double precision,
  longitude      double precision,
  notes          text,
  is_default     boolean default false,
  deleted_at     timestamptz,
  created_at     timestamptz default now(),
  updated_at     timestamptz default now()
);

-- -------------------------------------
-- 3. laundry_services
-- -------------------------------------
create table if not exists laundry_services (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  service_type  text not null check (service_type in ('kiloan', 'satuan')),
  price         numeric not null default 0,
  unit          text not null default 'item',
  is_active     boolean default true,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- -------------------------------------
-- 4. orders
-- -------------------------------------
create table if not exists orders (
  id                    uuid primary key default gen_random_uuid(),
  order_code            text unique not null,
  customer_id           uuid not null references auth.users(id),
  address_id            uuid references addresses(id),
  order_type            text not null check (order_type in ('kiloan', 'satuan', 'campuran')),
  status                text not null default 'created' check (status in (
                          'created','waiting_pickup','picked_up','received_by_store',
                          'waiting_weight_input','waiting_payment','paid',
                          'washing','ironing','ready_to_deliver',
                          'out_for_delivery','completed','cancelled'
                        )),
  payment_status        text not null default 'pending' check (payment_status in (
                          'pending','waiting_verification','paid',
                          'rejected','failed','expired','cancelled'
                        )),
  subtotal              numeric default 0,
  delivery_fee          numeric default 0,
  discount_amount       numeric default 0,
  total_amount          numeric default 0,
  estimated_distance_km numeric,
  notes                 text,
  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);

-- -------------------------------------
-- 5. order_items
-- -------------------------------------
create table if not exists order_items (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references orders(id) on delete cascade,
  service_id    uuid references laundry_services(id),
  service_name  text not null,
  service_type  text not null check (service_type in ('kiloan', 'satuan')),
  quantity      numeric default 1,
  weight_kg     numeric,
  price         numeric not null default 0,
  subtotal      numeric not null default 0,
  notes         text,
  created_at    timestamptz default now()
);

-- -------------------------------------
-- 6. payments
-- -------------------------------------
create table if not exists payments (
  id                  uuid primary key default gen_random_uuid(),
  order_id            uuid not null references orders(id) on delete cascade,
  customer_id         uuid not null references auth.users(id),
  method              text not null check (method in ('manual_qris','manual_transfer','xendit','voucher')),
  provider            text not null default 'manual',
  amount              numeric not null default 0,
  status              text not null default 'pending' check (status in (
                        'pending','waiting_verification','paid',
                        'rejected','failed','expired','cancelled'
                      )),
  payment_proof_url   text,
  provider_reference  text,
  payment_url         text,
  paid_at             timestamptz,
  created_at          timestamptz default now(),
  updated_at          timestamptz default now()
);

-- -------------------------------------
-- 7. courier_tasks
-- -------------------------------------
create table if not exists courier_tasks (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders(id) on delete cascade,
  courier_id   uuid not null references auth.users(id),
  task_type    text not null check (task_type in ('pickup', 'delivery')),
  status       text not null default 'assigned' check (status in (
                 'assigned','on_the_way','picked_up',
                 'delivered','completed','cancelled'
               )),
  assigned_at  timestamptz default now(),
  completed_at timestamptz,
  notes        text,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

-- -------------------------------------
-- 8. order_status_histories
-- -------------------------------------
create table if not exists order_status_histories (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders(id) on delete cascade,
  status      text not null,
  changed_by  uuid references auth.users(id),
  note        text,
  created_at  timestamptz default now()
);

-- -------------------------------------
-- 9. laundry_photos
-- -------------------------------------
create table if not exists laundry_photos (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders(id) on delete cascade,
  uploaded_by  uuid references auth.users(id),
  photo_type   text not null default 'condition' check (photo_type in (
                 'condition','pickup_proof','delivery_proof','payment_proof'
               )),
  file_url     text not null,
  description  text,
  created_at   timestamptz default now()
);

-- -------------------------------------
-- 10. user_devices
-- -------------------------------------
create table if not exists user_devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  fcm_token   text not null,
  platform    text,
  is_active   boolean default true,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now(),
  unique (user_id, fcm_token)
);

-- -------------------------------------
-- 11. vouchers
-- -------------------------------------
create table if not exists vouchers (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  code              text unique not null,
  type              text not null default 'free_laundry',
  discount_percent  numeric default 100,
  max_discount      numeric,
  status            text not null default 'active' check (status in (
                      'active','used','expired','cancelled'
                    )),
  expired_at        timestamptz,
  used_order_id     uuid references orders(id),
  created_at        timestamptz default now(),
  used_at           timestamptz
);

-- -------------------------------------
-- 12. loyalty_points
-- -------------------------------------
create table if not exists loyalty_points (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references auth.users(id) on delete cascade,
  total_completed_orders  int default 0,
  current_cycle_count     int default 0,
  total_vouchers_earned   int default 0,
  created_at              timestamptz default now(),
  updated_at              timestamptz default now(),
  unique (user_id)
);

-- -------------------------------------
-- 13. delivery_fees
-- -------------------------------------
create table if not exists delivery_fees (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  min_distance_km  numeric default 0,
  max_distance_km  numeric,
  fee              numeric not null default 0,
  is_active        boolean default true,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

-- -------------------------------------
-- 14. settings
-- -------------------------------------
create table if not exists settings (
  id          uuid primary key default gen_random_uuid(),
  key         text unique not null,
  value       text,
  is_public   boolean default true,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- Migrasi: tambah kolom baru jika tabel sudah ada sebelumnya
alter table settings      add column if not exists is_public boolean default true;
alter table profiles      add column if not exists avatar_url text;
alter table courier_tasks add column if not exists completed_at timestamptz;
alter table addresses     add column if not exists deleted_at timestamptz;

update payments
set paid_at = coalesce(updated_at, created_at, now())
where status = 'paid'
  and paid_at is null;

-- Bersihkan data master yang terlanjur dobel sebelum unique index dibuat.
with duplicate_services as (
  select
    id,
    first_value(id) over (
      partition by lower(btrim(name)), service_type, price, lower(btrim(unit))
      order by created_at, id
    ) as keep_id
  from laundry_services
)
update order_items oi
set service_id = duplicate_services.keep_id
from duplicate_services
where oi.service_id = duplicate_services.id
  and duplicate_services.id <> duplicate_services.keep_id;

with duplicate_services as (
  select
    id,
    first_value(id) over (
      partition by lower(btrim(name)), service_type, price, lower(btrim(unit))
      order by created_at, id
    ) as keep_id
  from laundry_services
)
delete from laundry_services ls
using duplicate_services
where ls.id = duplicate_services.id
  and duplicate_services.id <> duplicate_services.keep_id;

with duplicate_fees as (
  select
    id,
    row_number() over (
      partition by lower(btrim(name)), min_distance_km, coalesce(max_distance_km, -1), fee
      order by is_active desc, created_at, id
    ) as rn
  from delivery_fees
)
delete from delivery_fees df
using duplicate_fees
where df.id = duplicate_fees.id
  and duplicate_fees.rn > 1;

-- =============================================================================
-- SECTION 3: INDEXES (performance)
-- =============================================================================

create index if not exists idx_profiles_user_id          on profiles(user_id);
create index if not exists idx_addresses_user_id         on addresses(user_id);
create index if not exists idx_addresses_user_active     on addresses(user_id) where deleted_at is null;
create index if not exists idx_orders_customer_id        on orders(customer_id);
create index if not exists idx_orders_status             on orders(status);
create index if not exists idx_orders_payment_status     on orders(payment_status);
create index if not exists idx_order_items_order_id      on order_items(order_id);
create index if not exists idx_payments_order_id         on payments(order_id);
create index if not exists idx_payments_customer_id      on payments(customer_id);
create index if not exists idx_courier_tasks_order_id    on courier_tasks(order_id);
create index if not exists idx_courier_tasks_courier_id  on courier_tasks(courier_id);
create index if not exists idx_order_histories_order_id  on order_status_histories(order_id);
create index if not exists idx_laundry_photos_order_id   on laundry_photos(order_id);
create index if not exists idx_user_devices_user_id      on user_devices(user_id);
create index if not exists idx_vouchers_user_id          on vouchers(user_id);
create index if not exists idx_vouchers_code             on vouchers(code);
create index if not exists idx_loyalty_points_user_id    on loyalty_points(user_id);
create unique index if not exists uniq_laundry_services_business_identity
  on laundry_services (lower(btrim(name)), service_type, price, lower(btrim(unit)));
create unique index if not exists uniq_delivery_fees_business_identity
  on delivery_fees (lower(btrim(name)), min_distance_km, coalesce(max_distance_km, -1), fee);


-- =============================================================================
-- SECTION 4: FUNCTIONS & TRIGGERS
-- =============================================================================

-- Drop triggers dulu supaya aman di-re-run
drop trigger if exists trg_profiles_updated_at         on profiles;
drop trigger if exists trg_addresses_updated_at        on addresses;
drop trigger if exists trg_laundry_services_updated_at on laundry_services;
drop trigger if exists trg_orders_updated_at           on orders;
drop trigger if exists trg_payments_updated_at         on payments;
drop trigger if exists trg_courier_tasks_updated_at    on courier_tasks;
drop trigger if exists trg_user_devices_updated_at     on user_devices;
drop trigger if exists trg_loyalty_points_updated_at   on loyalty_points;
drop trigger if exists trg_settings_updated_at         on settings;
drop trigger if exists trg_on_auth_user_created        on auth.users;
drop trigger if exists trg_order_status_history        on orders;
drop trigger if exists trg_sync_order_payment_status   on payments;

-- updated_at otomatis
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at
  before update on profiles
  for each row execute function set_updated_at();

create trigger trg_addresses_updated_at
  before update on addresses
  for each row execute function set_updated_at();

create trigger trg_laundry_services_updated_at
  before update on laundry_services
  for each row execute function set_updated_at();

create trigger trg_orders_updated_at
  before update on orders
  for each row execute function set_updated_at();

create trigger trg_payments_updated_at
  before update on payments
  for each row execute function set_updated_at();

create trigger trg_courier_tasks_updated_at
  before update on courier_tasks
  for each row execute function set_updated_at();

create trigger trg_user_devices_updated_at
  before update on user_devices
  for each row execute function set_updated_at();

create trigger trg_loyalty_points_updated_at
  before update on loyalty_points
  for each row execute function set_updated_at();

create trigger trg_settings_updated_at
  before update on settings
  for each row execute function set_updated_at();

-- Auto-create profile saat user baru register
-- SET search_path diperlukan di Supabase modern untuk security definer functions
create or replace function handle_new_user()
returns trigger language plpgsql security definer
SET search_path = public
as $$
begin
  insert into profiles (user_id, name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'phone',
    coalesce(new.raw_user_meta_data->>'role', 'customer')
  )
  on conflict (user_id) do update
    set name = excluded.name,
        phone = excluded.phone,
        role = excluded.role;

  insert into loyalty_points (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Auto-record order status history saat status order berubah
create or replace function record_order_status_history()
returns trigger language plpgsql security definer as $$
begin
  if old.status is distinct from new.status then
    insert into order_status_histories (order_id, status, changed_by)
    values (new.id, new.status, auth.uid());
  end if;
  return new;
end;
$$;

create trigger trg_order_status_history
  after update on orders
  for each row execute function record_order_status_history();

-- Auto-sync payment_status di orders saat payment berubah
create or replace function sync_order_payment_status()
returns trigger language plpgsql security definer as $$
begin
  if new.status = 'paid' then
    update orders
    set payment_status = 'paid', updated_at = now()
    where id = new.order_id;
  elsif new.status = 'waiting_verification' then
    update orders
    set payment_status = 'waiting_verification', updated_at = now()
    where id = new.order_id;
  elsif new.status in ('rejected', 'failed', 'expired', 'cancelled') then
    update orders
    set payment_status = new.status, updated_at = now()
    where id = new.order_id;
  end if;
  return new;
end;
$$;

create trigger trg_sync_order_payment_status
  after update on payments
  for each row execute function sync_order_payment_status();

-- Saat order dibatalkan: batalkan tugas kurir yang masih aktif (mencegah
-- kurir menghidupkan ulang order via update status tugas) dan kembalikan
-- voucher yang sudah dipakai ke status 'active'.
create or replace function handle_order_cancelled()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    update courier_tasks
    set status = 'cancelled', updated_at = now()
    where order_id = new.id
      and status in ('assigned', 'on_the_way');

    update vouchers
    set status = 'active', used_order_id = null, used_at = null
    where used_order_id = new.id
      and status = 'used';
  end if;
  return new;
end;
$$;

create trigger trg_handle_order_cancelled
  after update on orders
  for each row execute function handle_order_cancelled();

-- Customer hanya boleh mengubah status order miliknya jadi 'cancelled',
-- dan hanya selama order masih berstatus 'created'.
create or replace function enforce_customer_order_status_transition()
returns trigger language plpgsql security definer
set search_path = public
as $$
begin
  if get_my_role() = 'customer' and new.status is distinct from old.status then
    if new.status <> 'cancelled'
       or old.status <> 'created'
       or old.payment_status <> 'pending' then
      raise exception
        'Pelanggan hanya bisa membatalkan pesanan yang masih berstatus "created" dan belum ada pembayaran berjalan';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_enforce_customer_order_status
  before update on orders
  for each row execute function enforce_customer_order_status_transition();


-- =============================================================================
-- SECTION 5: RLS — ROW LEVEL SECURITY
-- =============================================================================

-- Drop semua policy yang ada dulu supaya aman di-re-run
do $$
declare
  r record;
begin
  for r in (
    select schemaname, tablename, policyname
    from pg_policies
    where tablename in (
      'profiles','addresses','laundry_services','orders','order_items',
      'payments','courier_tasks','order_status_histories','laundry_photos',
      'user_devices','vouchers','loyalty_points','delivery_fees','settings'
    )
  ) loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- Helper: ambil role user yang sedang login (dipanggil sekali per query)
create or replace function get_my_role()
returns text language sql stable security definer as $$
  select role from profiles where user_id = auth.uid() limit 1;
$$;

-- -------------------------------------
-- profiles
-- -------------------------------------
alter table profiles enable row level security;

create policy "profiles: user can read own"
  on profiles for select using (user_id = auth.uid());

create policy "profiles: user can update own"
  on profiles for update using (user_id = auth.uid());

create policy "profiles: user can insert own"
  on profiles for insert with check (user_id = auth.uid());

create policy "profiles: admin can read all"
  on profiles for select using (get_my_role() = 'admin');

create policy "profiles: admin can update all"
  on profiles for update using (get_my_role() = 'admin');

create policy "profiles: courier can read assigned customers"
  on profiles for select using (
    get_my_role() = 'courier'
    and exists (
      select 1
      from orders
      join courier_tasks on courier_tasks.order_id = orders.id
      where orders.customer_id = profiles.user_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- -------------------------------------
-- addresses
-- -------------------------------------
alter table addresses enable row level security;

create policy "addresses: user can read own"
  on addresses for select using (user_id = auth.uid());

create policy "addresses: user can insert own"
  on addresses for insert with check (user_id = auth.uid());

create policy "addresses: user can update own"
  on addresses for update using (user_id = auth.uid());

create policy "addresses: user can delete own"
  on addresses for delete using (user_id = auth.uid());

create policy "addresses: admin can read all"
  on addresses for select using (get_my_role() = 'admin');

create policy "addresses: courier can read assigned order addresses"
  on addresses for select using (
    get_my_role() = 'courier'
    and exists (
      select 1
      from orders
      join courier_tasks on courier_tasks.order_id = orders.id
      where orders.address_id = addresses.id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- -------------------------------------
-- laundry_services
-- -------------------------------------
alter table laundry_services enable row level security;

create policy "laundry_services: authenticated can read active"
  on laundry_services for select
  using (is_active = true and auth.role() = 'authenticated');

create policy "laundry_services: admin can read all"
  on laundry_services for select using (get_my_role() = 'admin');

create policy "laundry_services: admin can insert"
  on laundry_services for insert with check (get_my_role() = 'admin');

create policy "laundry_services: admin can update"
  on laundry_services for update using (get_my_role() = 'admin');

create policy "laundry_services: admin can delete"
  on laundry_services for delete using (get_my_role() = 'admin');

-- -------------------------------------
-- orders
-- -------------------------------------
alter table orders enable row level security;

create policy "orders: customer can read own"
  on orders for select using (customer_id = auth.uid());

create policy "orders: customer can insert"
  on orders for insert with check (customer_id = auth.uid());

create policy "orders: customer can update own"
  on orders for update using (customer_id = auth.uid());

create policy "orders: courier can read assigned"
  on orders for select using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = orders.id
        and courier_tasks.courier_id = auth.uid()
    )
  );

create policy "orders: courier can update assigned"
  on orders for update using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = orders.id
        and courier_tasks.courier_id = auth.uid()
    )
  ) with check (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = orders.id
        and courier_tasks.courier_id = auth.uid()
    )
  );

create policy "orders: admin can read all"
  on orders for select using (get_my_role() = 'admin');

create policy "orders: admin can update all"
  on orders for update using (get_my_role() = 'admin');

-- -------------------------------------
-- order_items
-- -------------------------------------
alter table order_items enable row level security;

create policy "order_items: customer can read own"
  on order_items for select using (
    exists (
      select 1 from orders
      where orders.id = order_items.order_id
        and orders.customer_id = auth.uid()
    )
  );

create policy "order_items: customer can insert own"
  on order_items for insert with check (
    exists (
      select 1 from orders
      where orders.id = order_items.order_id
        and orders.customer_id = auth.uid()
    )
  );

create policy "order_items: courier can read assigned"
  on order_items for select using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = order_items.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

create policy "order_items: admin can read all"
  on order_items for select using (get_my_role() = 'admin');

create policy "order_items: admin can insert"
  on order_items for insert with check (get_my_role() = 'admin');

create policy "order_items: admin can update"
  on order_items for update using (get_my_role() = 'admin');

create policy "order_items: admin can delete"
  on order_items for delete using (get_my_role() = 'admin');

-- -------------------------------------
-- payments
-- -------------------------------------
alter table payments enable row level security;

create policy "payments: customer can read own"
  on payments for select using (customer_id = auth.uid());

create policy "payments: customer can insert own"
  on payments for insert with check (
    customer_id = auth.uid()
    and exists (
      select 1 from orders
      where orders.id = payments.order_id
        and orders.customer_id = auth.uid()
    )
  );

create policy "payments: customer can update own"
  on payments for update using (customer_id = auth.uid());

create policy "payments: admin can read all"
  on payments for select using (get_my_role() = 'admin');

create policy "payments: admin can update all"
  on payments for update using (get_my_role() = 'admin');

-- -------------------------------------
-- courier_tasks
-- -------------------------------------
alter table courier_tasks enable row level security;

create policy "courier_tasks: courier can read own"
  on courier_tasks for select using (courier_id = auth.uid());

create policy "courier_tasks: courier can update own"
  on courier_tasks for update using (courier_id = auth.uid());

create policy "courier_tasks: admin can read all"
  on courier_tasks for select using (get_my_role() = 'admin');

create policy "courier_tasks: admin can insert"
  on courier_tasks for insert with check (get_my_role() = 'admin');

create policy "courier_tasks: admin can update all"
  on courier_tasks for update using (get_my_role() = 'admin');

create policy "courier_tasks: admin can delete"
  on courier_tasks for delete using (get_my_role() = 'admin');

-- -------------------------------------
-- order_status_histories
-- -------------------------------------
alter table order_status_histories enable row level security;

create policy "order_status_histories: customer can read own"
  on order_status_histories for select using (
    exists (
      select 1 from orders
      where orders.id = order_status_histories.order_id
        and orders.customer_id = auth.uid()
    )
  );

create policy "order_status_histories: courier can read assigned"
  on order_status_histories for select using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = order_status_histories.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

create policy "order_status_histories: admin can read all"
  on order_status_histories for select using (get_my_role() = 'admin');

create policy "order_status_histories: admin can insert"
  on order_status_histories for insert with check (get_my_role() = 'admin');

create policy "order_status_histories: courier can insert assigned"
  on order_status_histories for insert with check (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = order_status_histories.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- -------------------------------------
-- laundry_photos
-- -------------------------------------
alter table laundry_photos enable row level security;

create policy "laundry_photos: customer can read own"
  on laundry_photos for select using (
    exists (
      select 1 from orders
      where orders.id = laundry_photos.order_id
        and orders.customer_id = auth.uid()
    )
  );

create policy "laundry_photos: customer can insert own"
  on laundry_photos for insert with check (
    uploaded_by = auth.uid()
    and exists (
      select 1 from orders
      where orders.id = laundry_photos.order_id
        and orders.customer_id = auth.uid()
    )
  );

create policy "laundry_photos: courier can read assigned"
  on laundry_photos for select using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = laundry_photos.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

create policy "laundry_photos: courier can insert assigned"
  on laundry_photos for insert with check (
    uploaded_by = auth.uid()
    and get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = laundry_photos.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

create policy "laundry_photos: admin can read all"
  on laundry_photos for select using (get_my_role() = 'admin');

create policy "laundry_photos: admin can insert"
  on laundry_photos for insert with check (get_my_role() = 'admin');

-- -------------------------------------
-- user_devices
-- -------------------------------------
alter table user_devices enable row level security;

create policy "user_devices: user can read own"
  on user_devices for select using (user_id = auth.uid());

create policy "user_devices: user can insert own"
  on user_devices for insert with check (user_id = auth.uid());

create policy "user_devices: user can update own"
  on user_devices for update using (user_id = auth.uid());

create policy "user_devices: user can delete own"
  on user_devices for delete using (user_id = auth.uid());

create policy "user_devices: admin can read all"
  on user_devices for select using (get_my_role() = 'admin');

-- -------------------------------------
-- vouchers
-- -------------------------------------
alter table vouchers enable row level security;

create policy "vouchers: customer can read own"
  on vouchers for select using (user_id = auth.uid());

create policy "vouchers: customer can update own"
  on vouchers for update using (user_id = auth.uid());

create policy "vouchers: admin can read all"
  on vouchers for select using (get_my_role() = 'admin');

create policy "vouchers: admin can insert"
  on vouchers for insert with check (get_my_role() = 'admin');

create policy "vouchers: admin can update"
  on vouchers for update using (get_my_role() = 'admin');

-- -------------------------------------
-- loyalty_points
-- -------------------------------------
alter table loyalty_points enable row level security;

create policy "loyalty_points: customer can read own"
  on loyalty_points for select using (user_id = auth.uid());

create policy "loyalty_points: admin can read all"
  on loyalty_points for select using (get_my_role() = 'admin');

create policy "loyalty_points: admin can insert"
  on loyalty_points for insert with check (get_my_role() = 'admin');

create policy "loyalty_points: admin can update"
  on loyalty_points for update using (get_my_role() = 'admin');

-- -------------------------------------
-- delivery_fees
-- -------------------------------------
alter table delivery_fees enable row level security;

create policy "delivery_fees: authenticated can read active"
  on delivery_fees for select
  using (is_active = true and auth.role() = 'authenticated');

create policy "delivery_fees: admin can read all"
  on delivery_fees for select using (get_my_role() = 'admin');

create policy "delivery_fees: admin can insert"
  on delivery_fees for insert with check (get_my_role() = 'admin');

create policy "delivery_fees: admin can update"
  on delivery_fees for update using (get_my_role() = 'admin');

create policy "delivery_fees: admin can delete"
  on delivery_fees for delete using (get_my_role() = 'admin');

-- -------------------------------------
-- settings
-- -------------------------------------
alter table settings enable row level security;

create policy "settings: authenticated can read public"
  on settings for select
  using (is_public = true and auth.role() = 'authenticated');

create policy "settings: admin can read all"
  on settings for select using (get_my_role() = 'admin');

create policy "settings: admin can insert"
  on settings for insert with check (get_my_role() = 'admin');

create policy "settings: admin can update"
  on settings for update using (get_my_role() = 'admin');

create policy "settings: admin can delete"
  on settings for delete using (get_my_role() = 'admin');


-- =============================================================================
-- SECTION 6: REALTIME
-- Aktifkan realtime untuk tabel yang butuh update live di client
-- =============================================================================

-- orders       → customer tracking status pesanan secara realtime
-- courier_tasks → kurir menerima/update task secara realtime
-- payments      → customer & admin update status bayar secara realtime
-- order_status_histories → customer lihat timeline status secara realtime
-- laundry_photos → customer/kurir lihat foto baru secara realtime

do $$
declare
  t text;
begin
  foreach t in array array['orders','courier_tasks','payments','order_status_histories','laundry_photos']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end $$;


-- =============================================================================
-- SECTION 7: SEED DATA (opsional, hapus jika tidak diperlukan)
-- =============================================================================

-- -------------------------------------
-- Akun test (admin / kurir / customer)
-- Trigger handle_new_user() akan otomatis buat profiles + loyalty_points
-- Password default semua akun: Premier123!
-- -------------------------------------
do $$
declare
  v_admin_id    uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_courier_id  uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_customer_id uuid := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  v_instance    uuid := '00000000-0000-0000-0000-000000000000';
  v_now         timestamptz := now();
  v_meta        jsonb;
  v_seed        record;
begin
  v_meta := '{"provider":"email","providers":["email"]}'::jsonb;

  -- Hapus identity lama yang mungkin corrupt, lalu buat ulang.
  -- Untuk provider email Supabase Auth, provider_id harus sama dengan user_id.
  delete from auth.identities where user_id in (v_admin_id, v_courier_id, v_customer_id);

  for v_seed in
    select *
    from (values
      (v_admin_id,    'admin@premierlaundry.com',    'Admin Premier', 'admin'),
      (v_courier_id,  'kurir@premierlaundry.com',    'Budi Kurir',    'courier'),
      (v_customer_id, 'customer@premierlaundry.com', 'Andi Customer', 'customer')
    ) as seed(user_id, email, name, app_role)
  loop
    insert into auth.users (
      instance_id, id, aud, role,
      email, encrypted_password,
      email_confirmed_at, last_sign_in_at,
      phone, phone_change, phone_change_token,
      raw_app_meta_data, raw_user_meta_data,
      is_sso_user, is_anonymous,
      created_at, updated_at,
      confirmation_token, recovery_token,
      email_change, email_change_token_current, email_change_token_new,
      email_change_confirm_status, reauthentication_token
    ) values (
      v_instance, v_seed.user_id, 'authenticated', 'authenticated',
      v_seed.email,
      crypt('Premier123!', gen_salt('bf')),
      v_now, v_now,
      null, '', '',
      v_meta, jsonb_build_object('name', v_seed.name, 'role', v_seed.app_role),
      false, false,
      v_now, v_now,
      '', '',
      '', '', '',
      0, ''
    ) on conflict (id) do update
      set email               = excluded.email,
          encrypted_password  = excluded.encrypted_password,
          email_confirmed_at  = excluded.email_confirmed_at,
          last_sign_in_at     = excluded.last_sign_in_at,
          phone               = excluded.phone,
          phone_change        = excluded.phone_change,
          phone_change_token  = excluded.phone_change_token,
          raw_app_meta_data   = excluded.raw_app_meta_data,
          raw_user_meta_data  = excluded.raw_user_meta_data,
          is_sso_user         = excluded.is_sso_user,
          is_anonymous        = excluded.is_anonymous,
          confirmation_token  = excluded.confirmation_token,
          recovery_token      = excluded.recovery_token,
          email_change        = excluded.email_change,
          email_change_token_current = excluded.email_change_token_current,
          email_change_token_new = excluded.email_change_token_new,
          email_change_confirm_status = excluded.email_change_confirm_status,
          reauthentication_token = excluded.reauthentication_token,
          updated_at          = excluded.updated_at;

    insert into auth.identities (
      provider_id, user_id,
      identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      v_seed.user_id::text, v_seed.user_id,
      jsonb_build_object(
        'sub',            v_seed.user_id::text,
        'email',          v_seed.email,
        'email_verified', true,
        'phone_verified', false
      ),
      'email', v_now, v_now, v_now
    ) on conflict (provider_id, provider) do update
      set user_id        = excluded.user_id,
          identity_data  = excluded.identity_data,
          last_sign_in_at = excluded.last_sign_in_at,
          updated_at     = excluded.updated_at;
  end loop;

end $$;

-- Pastikan profiles ada (trigger tidak fire saat upsert UPDATE path)
insert into profiles (user_id, name, role) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Admin Premier',  'admin'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Budi Kurir',     'courier'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Andi Customer',  'customer')
on conflict (user_id) do update
  set name = excluded.name,
      role = excluded.role;

-- Pastikan loyalty_points ada untuk customer
insert into loyalty_points (user_id) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc')
on conflict (user_id) do nothing;

-- Seed alamat untuk akun customer test
insert into addresses (user_id, label, address_text, latitude, longitude, is_default)
values (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'Rumah',
  'Jl. Contoh No. 10, Jakarta Selatan',
  -6.261493,
  106.810600,
  true
) on conflict do nothing;

-- -------------------------------------
-- Layanan laundry default
-- -------------------------------------
with desired_services (name, service_type, price, unit) as (
  values
    ('Reguler - Cuci Setrika', 'kiloan', 7000,  'kg'),
    ('Reguler - Cuci Lipat',   'kiloan', 6000,  'kg'),
    ('Reguler - Setrika',      'kiloan', 6000,  'kg'),
    ('Express - Cuci Setrika', 'kiloan', 10000, 'kg'),
    ('Express - Cuci Lipat',   'kiloan', 8000,  'kg'),
    ('Express - Setrika',      'kiloan', 8000,  'kg'),
    ('Kilat - Cuci Setrika',   'kiloan', 12000, 'kg'),
    ('Kilat - Cuci Lipat',     'kiloan', 10000, 'kg'),
    ('Kilat - Setrika',        'kiloan', 10000, 'kg'),
    ('Selimut Kecil',          'satuan', 10000, 'item'),
    ('Selimut Sedang',         'satuan', 15000, 'item'),
    ('Bedcover Kecil',         'satuan', 30000, 'item'),
    ('Bedcover Besar',         'satuan', 40000, 'item'),
    ('Sprei',                  'satuan', 12000, 'item'),
    ('Sprei + Sarung Bantal',  'satuan', 15000, 'item'),
    ('Jas',                    'satuan', 30000, 'item'),
    ('Celana Pendek',          'satuan', 15000, 'item'),
    ('Paket Jas + Celana',     'satuan', 45000, 'paket'),
    ('Celana Panjang',         'satuan', 20000, 'item'),
    ('Kemeja',                 'satuan', 20000, 'item'),
    ('Sepatu',                 'satuan', 35000, 'pasang'),
    ('Helm',                   'satuan', 35000, 'item')
),
deactivated as (
  update laundry_services ls
  set is_active = false
  where not exists (
    select 1
    from desired_services ds
    where lower(btrim(ds.name)) = lower(btrim(ls.name))
      and ds.service_type = ls.service_type
      and ds.price = ls.price
      and lower(btrim(ds.unit)) = lower(btrim(ls.unit))
  )
),
reactivated as (
  update laundry_services ls
  set is_active = true
  where exists (
    select 1
    from desired_services ds
    where lower(btrim(ds.name)) = lower(btrim(ls.name))
      and ds.service_type = ls.service_type
      and ds.price = ls.price
      and lower(btrim(ds.unit)) = lower(btrim(ls.unit))
  )
)
insert into laundry_services (name, service_type, price, unit, is_active)
select name, service_type, price, unit, true
from desired_services ds
where not exists (
  select 1
  from laundry_services ls
  where lower(btrim(ls.name)) = lower(btrim(ds.name))
    and ls.service_type = ds.service_type
    and ls.price = ds.price
    and lower(btrim(ls.unit)) = lower(btrim(ds.unit))
);

-- Ongkir default
insert into delivery_fees (name, min_distance_km, max_distance_km, fee) values
  ('0 - 2 km',  0, 2,    5000),
  ('2 - 5 km',  2, 5,    10000),
  ('5 - 8 km',  5, 8,    15000),
  ('> 8 km',    8, null, 20000)
on conflict do nothing;

-- Settings default
insert into settings (key, value, is_public) values
  ('store_name',           'Premier Laundry',  true),
  ('store_latitude',       '-6.200000',         true),
  ('store_longitude',      '106.816666',        true),
  ('store_phone',          '08xxxxxxxxxx',      true),
  ('qris_image_url',       '',                  true),
  ('xendit_callback_token','',                  false),
  ('min_order_kg',         '1',                 true),
  ('loyalty_cycle_target', '10',                true)
on conflict (key) do nothing;
