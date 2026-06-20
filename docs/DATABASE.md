# DATABASE.md

## Overview

Database menggunakan Supabase PostgreSQL. Struktur ini dibuat untuk MVP aplikasi Premier Laundry dengan 3 role: customer, courier, dan admin.

---

## 1. profiles

Menyimpan data profile dan role user.

```sql
create table profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  phone text,
  role text not null check (role in ('customer', 'courier', 'admin')),
  is_available boolean not null default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

`is_available` dipakai khusus untuk role courier (toggle "Aktif Menerima Tugas" di halaman Akun Kurir).

---

## 2. addresses

Menyimpan alamat dan titik koordinat customer.

```sql
create table addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text,
  address_text text not null,
  latitude double precision,
  longitude double precision,
  notes text,
  is_default boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

---

## 3. laundry_services

Menyimpan layanan laundry dan harga.

```sql
create table laundry_services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  service_type text not null check (service_type in ('kiloan', 'satuan')),
  price numeric not null default 0,
  unit text not null default 'item',
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

Contoh:

```text
Cuci Kiloan | kiloan | 8000 | kg
Kemeja      | satuan | 7000 | item
Jaket       | satuan | 15000 | item
```

---

## 4. orders

Menyimpan data utama order laundry.

```sql
create table orders (
  id uuid primary key default gen_random_uuid(),
  order_code text unique not null,
  customer_id uuid not null references auth.users(id),
  address_id uuid references addresses(id),
  order_type text not null check (order_type in ('kiloan', 'satuan', 'campuran')),
  status text not null default 'created',
  payment_status text not null default 'pending',
  subtotal numeric default 0,
  delivery_fee numeric default 0,
  discount_amount numeric default 0,
  total_amount numeric default 0,
  estimated_distance_km numeric,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

Recommended status:

```text
created
waiting_pickup
picked_up
received_by_store
waiting_weight_input
waiting_payment
paid
washing
ironing
ready_to_deliver
out_for_delivery
completed
cancelled
```

---

## 5. order_items

Menyimpan item layanan dalam order.

```sql
create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  service_id uuid references laundry_services(id),
  service_name text not null,
  service_type text not null check (service_type in ('kiloan', 'satuan')),
  quantity numeric default 1,
  weight_kg numeric,
  price numeric not null default 0,
  subtotal numeric not null default 0,
  notes text,
  created_at timestamptz default now()
);
```

---

## 6. payments

Menyimpan transaksi pembayaran manual dan payment gateway.

```sql
create table payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  customer_id uuid not null references auth.users(id),
  method text not null check (method in ('manual_qris', 'manual_transfer', 'xendit', 'voucher')),
  provider text not null default 'manual',
  amount numeric not null default 0,
  status text not null default 'pending',
  payment_proof_url text,
  provider_reference text,
  payment_url text,
  paid_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

Payment status:

```text
pending
waiting_verification
paid
rejected
failed
expired
cancelled
```

---

## 7. courier_tasks

Menyimpan tugas kurir untuk jemput dan antar.

```sql
create table courier_tasks (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  courier_id uuid not null references auth.users(id),
  task_type text not null check (task_type in ('pickup', 'delivery')),
  status text not null default 'assigned',
  assigned_at timestamptz default now(),
  completed_at timestamptz,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

Task status:

```text
assigned
on_the_way
picked_up
delivered
completed
cancelled
```

---

## 8. order_status_histories

Menyimpan histori perubahan status order.

```sql
create table order_status_histories (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  status text not null,
  changed_by uuid references auth.users(id),
  note text,
  created_at timestamptz default now()
);
```

---

## 9. laundry_photos

Menyimpan foto pakaian, bukti kondisi, atau dokumentasi proses.

```sql
create table laundry_photos (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  uploaded_by uuid references auth.users(id),
  photo_type text not null default 'condition',
  file_url text not null,
  description text,
  created_at timestamptz default now()
);
```

Photo type:

```text
condition
pickup_proof
delivery_proof
payment_proof
```

---

## 10. user_devices

Menyimpan FCM token untuk push notification.

```sql
create table user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null,
  platform text,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

---

## 11. vouchers

Menyimpan voucher customer.

```sql
create table vouchers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  code text unique not null,
  type text not null default 'free_laundry',
  discount_percent numeric default 100,
  max_discount numeric,
  status text not null default 'active',
  expired_at timestamptz,
  used_order_id uuid references orders(id),
  created_at timestamptz default now(),
  used_at timestamptz
);
```

Voucher status:

```text
active
used
expired
cancelled
```

---

## 12. loyalty_points

Menyimpan akumulasi jumlah order selesai.

```sql
create table loyalty_points (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  total_completed_orders int default 0,
  current_cycle_count int default 0,
  total_vouchers_earned int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

Rule MVP:

```text
Jika order completed → current_cycle_count + 1
Jika current_cycle_count mencapai 10 → generate voucher dan reset current_cycle_count ke 0
```

---

## 13. delivery_fees

Menyimpan konfigurasi ongkir sederhana.

```sql
create table delivery_fees (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  min_distance_km numeric default 0,
  max_distance_km numeric,
  fee numeric not null default 0,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

Contoh:

```text
0 - 2 km  = Rp5.000
2 - 5 km  = Rp10.000
5 - 8 km  = Rp15.000
```

---

## 14. settings

Menyimpan konfigurasi umum aplikasi.

```sql
create table settings (
  id uuid primary key default gen_random_uuid(),
  key text unique not null,
  value text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

Contoh setting:

```text
store_latitude
store_longitude
qris_image_url
xendit_callback_token
```

---

## Basic RLS Concept

### Customer

- Boleh membaca profile sendiri.
- Boleh membaca order miliknya.
- Boleh membuat order baru.
- Boleh upload bukti pembayaran miliknya.

### Courier

- Boleh membaca courier task miliknya.
- Boleh update status courier task miliknya.

### Admin

- Boleh membaca semua order.
- Boleh update semua order.
- Boleh validasi payment.
- Boleh mengelola service dan harga.

---

## Recommended Storage Buckets

```text
payment-proofs
laundry-photos
profile-photos   -- public bucket, dipakai foto profil customer/kurir/admin
                 -- (lihat add_profile_photos_storage.sql untuk policy-nya)
qris-assets
```

---

## Recommended Edge Functions

```text
send-notification
create-xendit-invoice
xendit-webhook
calculate-delivery-fee
complete-order-generate-loyalty
```
