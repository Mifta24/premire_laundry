# RLS.md — Row Level Security Policies

## Catatan Penggunaan

- Jalankan semua SQL ini di Supabase SQL Editor setelah membuat tabel.
- RLS diaktifkan per tabel, lalu policy ditambahkan untuk setiap role.
- Role ditentukan dari kolom `role` di tabel `profiles`.
- Helper function `get_my_role()` digunakan untuk efisiensi agar tidak memanggil subquery berulang.

---

## Helper Function

```sql
-- Helper: ambil role user yang sedang login
create or replace function get_my_role()
returns text
language sql
stable
security definer
as $$
  select role from profiles where user_id = auth.uid() limit 1;
$$;
```

---

## 1. profiles

```sql
alter table profiles enable row level security;

-- User boleh baca profile sendiri
create policy "profiles: user can read own"
  on profiles for select
  using (user_id = auth.uid());

-- User boleh update profile sendiri
create policy "profiles: user can update own"
  on profiles for update
  using (user_id = auth.uid());

-- Admin boleh baca semua profile
create policy "profiles: admin can read all"
  on profiles for select
  using (get_my_role() = 'admin');

-- Admin boleh update semua profile
create policy "profiles: admin can update all"
  on profiles for update
  using (get_my_role() = 'admin');

-- Kurir boleh baca profil customer dari order yang ditugaskan kepadanya
create policy "profiles: courier can read assigned customers"
  on profiles for select
  using (
    get_my_role() = 'courier'
    and exists (
      select 1
      from orders
      join courier_tasks on courier_tasks.order_id = orders.id
      where orders.customer_id = profiles.user_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- Insert hanya via trigger/service role (profile dibuat otomatis saat register)
-- Jika perlu insert manual dari client:
create policy "profiles: user can insert own"
  on profiles for insert
  with check (user_id = auth.uid());
```

---

## 2. addresses

```sql
alter table addresses enable row level security;

-- Customer boleh baca alamat sendiri
create policy "addresses: user can read own"
  on addresses for select
  using (user_id = auth.uid());

-- Customer boleh insert alamat sendiri
create policy "addresses: user can insert own"
  on addresses for insert
  with check (user_id = auth.uid());

-- Customer boleh update alamat sendiri
create policy "addresses: user can update own"
  on addresses for update
  using (user_id = auth.uid());

-- Customer boleh delete alamat sendiri
create policy "addresses: user can delete own"
  on addresses for delete
  using (user_id = auth.uid());

-- Admin boleh baca semua alamat
create policy "addresses: admin can read all"
  on addresses for select
  using (get_my_role() = 'admin');

-- Kurir boleh baca alamat order yang ditugaskan kepadanya
create policy "addresses: courier can read assigned order addresses"
  on addresses for select
  using (
    get_my_role() = 'courier'
    and exists (
      select 1
      from orders
      join courier_tasks on courier_tasks.order_id = orders.id
      where orders.address_id = addresses.id
        and courier_tasks.courier_id = auth.uid()
    )
  );
```

---

## 3. laundry_services

```sql
alter table laundry_services enable row level security;

-- Semua user login boleh baca layanan aktif
create policy "laundry_services: authenticated can read active"
  on laundry_services for select
  using (is_active = true and auth.role() = 'authenticated');

-- Admin boleh baca semua (termasuk non-aktif)
create policy "laundry_services: admin can read all"
  on laundry_services for select
  using (get_my_role() = 'admin');

-- Admin boleh insert
create policy "laundry_services: admin can insert"
  on laundry_services for insert
  with check (get_my_role() = 'admin');

-- Admin boleh update
create policy "laundry_services: admin can update"
  on laundry_services for update
  using (get_my_role() = 'admin');

-- Admin boleh delete
create policy "laundry_services: admin can delete"
  on laundry_services for delete
  using (get_my_role() = 'admin');
```

---

## 4. orders

```sql
alter table orders enable row level security;

-- Customer boleh baca order miliknya
create policy "orders: customer can read own"
  on orders for select
  using (customer_id = auth.uid());

-- Customer boleh buat order
create policy "orders: customer can insert"
  on orders for insert
  with check (customer_id = auth.uid());

-- Customer boleh update order miliknya (hanya status tertentu, logika di app)
create policy "orders: customer can update own"
  on orders for update
  using (customer_id = auth.uid());

-- Kurir boleh baca order yang memiliki courier_task miliknya
create policy "orders: courier can read assigned"
  on orders for select
  using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = orders.id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- Kurir boleh update order yang memiliki courier_task miliknya
create policy "orders: courier can update assigned"
  on orders for update
  using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = orders.id
        and courier_tasks.courier_id = auth.uid()
    )
  )
  with check (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = orders.id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- Admin boleh baca semua order
create policy "orders: admin can read all"
  on orders for select
  using (get_my_role() = 'admin');

-- Admin boleh update semua order
create policy "orders: admin can update all"
  on orders for update
  using (get_my_role() = 'admin');
```

---

## 5. order_items

```sql
alter table order_items enable row level security;

-- Customer boleh baca item order miliknya
create policy "order_items: customer can read own"
  on order_items for select
  using (
    exists (
      select 1 from orders
      where orders.id = order_items.order_id
        and orders.customer_id = auth.uid()
    )
  );

-- Customer boleh insert item untuk order miliknya
create policy "order_items: customer can insert own"
  on order_items for insert
  with check (
    exists (
      select 1 from orders
      where orders.id = order_items.order_id
        and orders.customer_id = auth.uid()
    )
  );

-- Kurir boleh baca item order yang ditugaskan
create policy "order_items: courier can read assigned"
  on order_items for select
  using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = order_items.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- Admin boleh baca semua
create policy "order_items: admin can read all"
  on order_items for select
  using (get_my_role() = 'admin');

-- Admin boleh insert/update/delete
create policy "order_items: admin can insert"
  on order_items for insert
  with check (get_my_role() = 'admin');

create policy "order_items: admin can update"
  on order_items for update
  using (get_my_role() = 'admin');

create policy "order_items: admin can delete"
  on order_items for delete
  using (get_my_role() = 'admin');
```

---

## 6. payments

```sql
alter table payments enable row level security;

-- Customer boleh baca payment miliknya
create policy "payments: customer can read own"
  on payments for select
  using (customer_id = auth.uid());

-- Customer boleh buat payment untuk order miliknya
create policy "payments: customer can insert own"
  on payments for insert
  with check (
    customer_id = auth.uid()
    and exists (
      select 1 from orders
      where orders.id = payments.order_id
        and orders.customer_id = auth.uid()
    )
  );

-- Customer boleh update payment miliknya (untuk upload bukti)
create policy "payments: customer can update own"
  on payments for update
  using (customer_id = auth.uid());

-- Admin boleh baca semua payment
create policy "payments: admin can read all"
  on payments for select
  using (get_my_role() = 'admin');

-- Admin boleh update semua payment (untuk verifikasi)
create policy "payments: admin can update all"
  on payments for update
  using (get_my_role() = 'admin');
```

---

## 7. courier_tasks

```sql
alter table courier_tasks enable row level security;

-- Kurir boleh baca task miliknya
create policy "courier_tasks: courier can read own"
  on courier_tasks for select
  using (courier_id = auth.uid());

-- Kurir boleh update task miliknya (update status)
create policy "courier_tasks: courier can update own"
  on courier_tasks for update
  using (courier_id = auth.uid());

-- Admin boleh baca semua task
create policy "courier_tasks: admin can read all"
  on courier_tasks for select
  using (get_my_role() = 'admin');

-- Admin boleh insert task (assign kurir)
create policy "courier_tasks: admin can insert"
  on courier_tasks for insert
  with check (get_my_role() = 'admin');

-- Admin boleh update semua task
create policy "courier_tasks: admin can update all"
  on courier_tasks for update
  using (get_my_role() = 'admin');

-- Admin boleh delete task
create policy "courier_tasks: admin can delete"
  on courier_tasks for delete
  using (get_my_role() = 'admin');
```

---

## 8. order_status_histories

```sql
alter table order_status_histories enable row level security;

-- Customer boleh baca histori order miliknya
create policy "order_status_histories: customer can read own"
  on order_status_histories for select
  using (
    exists (
      select 1 from orders
      where orders.id = order_status_histories.order_id
        and orders.customer_id = auth.uid()
    )
  );

-- Kurir boleh baca histori order yang ditugaskan
create policy "order_status_histories: courier can read assigned"
  on order_status_histories for select
  using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = order_status_histories.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- Admin boleh baca semua histori
create policy "order_status_histories: admin can read all"
  on order_status_histories for select
  using (get_my_role() = 'admin');

-- Admin boleh insert histori
create policy "order_status_histories: admin can insert"
  on order_status_histories for insert
  with check (get_my_role() = 'admin');

-- Kurir boleh insert histori untuk order yang ditugaskan
create policy "order_status_histories: courier can insert assigned"
  on order_status_histories for insert
  with check (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = order_status_histories.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );
```

---

## 9. laundry_photos

```sql
alter table laundry_photos enable row level security;

-- Customer boleh baca foto order miliknya
create policy "laundry_photos: customer can read own"
  on laundry_photos for select
  using (
    exists (
      select 1 from orders
      where orders.id = laundry_photos.order_id
        and orders.customer_id = auth.uid()
    )
  );

-- Customer boleh upload foto untuk order miliknya
create policy "laundry_photos: customer can insert own"
  on laundry_photos for insert
  with check (
    uploaded_by = auth.uid()
    and exists (
      select 1 from orders
      where orders.id = laundry_photos.order_id
        and orders.customer_id = auth.uid()
    )
  );

-- Kurir boleh baca foto order yang ditugaskan
create policy "laundry_photos: courier can read assigned"
  on laundry_photos for select
  using (
    get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = laundry_photos.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- Kurir boleh upload foto untuk order yang ditugaskan
create policy "laundry_photos: courier can insert assigned"
  on laundry_photos for insert
  with check (
    uploaded_by = auth.uid()
    and get_my_role() = 'courier'
    and exists (
      select 1 from courier_tasks
      where courier_tasks.order_id = laundry_photos.order_id
        and courier_tasks.courier_id = auth.uid()
    )
  );

-- Admin boleh baca semua foto
create policy "laundry_photos: admin can read all"
  on laundry_photos for select
  using (get_my_role() = 'admin');

-- Admin boleh insert foto
create policy "laundry_photos: admin can insert"
  on laundry_photos for insert
  with check (get_my_role() = 'admin');
```

---

## 10. user_devices

```sql
alter table user_devices enable row level security;

-- User boleh baca device miliknya
create policy "user_devices: user can read own"
  on user_devices for select
  using (user_id = auth.uid());

-- User boleh insert device miliknya
create policy "user_devices: user can insert own"
  on user_devices for insert
  with check (user_id = auth.uid());

-- User boleh update device miliknya (refresh FCM token)
create policy "user_devices: user can update own"
  on user_devices for update
  using (user_id = auth.uid());

-- User boleh delete device miliknya (logout)
create policy "user_devices: user can delete own"
  on user_devices for delete
  using (user_id = auth.uid());

-- Admin boleh baca semua (untuk kirim notifikasi)
create policy "user_devices: admin can read all"
  on user_devices for select
  using (get_my_role() = 'admin');
```

---

## 11. vouchers

```sql
alter table vouchers enable row level security;

-- Customer boleh baca voucher miliknya
create policy "vouchers: customer can read own"
  on vouchers for select
  using (user_id = auth.uid());

-- Admin boleh baca semua voucher
create policy "vouchers: admin can read all"
  on vouchers for select
  using (get_my_role() = 'admin');

-- Admin boleh insert voucher
create policy "vouchers: admin can insert"
  on vouchers for insert
  with check (get_my_role() = 'admin');

-- Admin boleh update voucher
create policy "vouchers: admin can update"
  on vouchers for update
  using (get_my_role() = 'admin');

-- Customer boleh update voucher miliknya (untuk apply voucher ke order)
create policy "vouchers: customer can update own"
  on vouchers for update
  using (user_id = auth.uid());
```

---

## 12. loyalty_points

```sql
alter table loyalty_points enable row level security;

-- Customer boleh baca poin miliknya
create policy "loyalty_points: customer can read own"
  on loyalty_points for select
  using (user_id = auth.uid());

-- Admin boleh baca semua poin
create policy "loyalty_points: admin can read all"
  on loyalty_points for select
  using (get_my_role() = 'admin');

-- Admin boleh insert/update poin (generate dari Edge Function)
create policy "loyalty_points: admin can insert"
  on loyalty_points for insert
  with check (get_my_role() = 'admin');

create policy "loyalty_points: admin can update"
  on loyalty_points for update
  using (get_my_role() = 'admin');
```

> **Catatan:** Update loyalty_points sebaiknya dilakukan via Edge Function `complete-order-generate-loyalty` dengan `service_role` key, bukan langsung dari client.

---

## 13. delivery_fees

```sql
alter table delivery_fees enable row level security;

-- Semua user login boleh baca tarif aktif
create policy "delivery_fees: authenticated can read active"
  on delivery_fees for select
  using (is_active = true and auth.role() = 'authenticated');

-- Admin boleh baca semua (termasuk non-aktif)
create policy "delivery_fees: admin can read all"
  on delivery_fees for select
  using (get_my_role() = 'admin');

-- Admin boleh insert/update/delete
create policy "delivery_fees: admin can insert"
  on delivery_fees for insert
  with check (get_my_role() = 'admin');

create policy "delivery_fees: admin can update"
  on delivery_fees for update
  using (get_my_role() = 'admin');

create policy "delivery_fees: admin can delete"
  on delivery_fees for delete
  using (get_my_role() = 'admin');
```

---

## 14. settings

```sql
alter table settings enable row level security;

-- Semua user login boleh baca settings (non-sensitive)
create policy "settings: authenticated can read"
  on settings for select
  using (auth.role() = 'authenticated');

-- Admin boleh insert/update settings
create policy "settings: admin can insert"
  on settings for insert
  with check (get_my_role() = 'admin');

create policy "settings: admin can update"
  on settings for update
  using (get_my_role() = 'admin');

create policy "settings: admin can delete"
  on settings for delete
  using (get_my_role() = 'admin');
```

> **Catatan:** Jika ada setting sensitif (misal `xendit_callback_token`), pertimbangkan untuk hanya dibaca via Edge Function dengan `service_role` key, bukan dari client langsung. Bisa tambahkan kolom `is_public boolean default true` di tabel `settings` lalu filter di policy.

---

## Storage Bucket Policies

Atur di Supabase Dashboard → Storage → Policies, atau via SQL:

### payment-proofs

```sql
-- Customer boleh upload bukti bayar miliknya
create policy "payment-proofs: customer can upload"
  on storage.objects for insert
  with check (
    bucket_id = 'payment-proofs'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Customer boleh baca file miliknya
create policy "payment-proofs: customer can read own"
  on storage.objects for select
  using (
    bucket_id = 'payment-proofs'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Admin boleh baca semua
create policy "payment-proofs: admin can read all"
  on storage.objects for select
  using (
    bucket_id = 'payment-proofs'
    and get_my_role() = 'admin'
  );
```

### laundry-photos

```sql
-- User login boleh upload foto laundry
create policy "laundry-photos: authenticated can upload"
  on storage.objects for insert
  with check (
    bucket_id = 'laundry-photos'
    and auth.role() = 'authenticated'
  );

-- User login boleh baca foto laundry
create policy "laundry-photos: authenticated can read"
  on storage.objects for select
  using (
    bucket_id = 'laundry-photos'
    and auth.role() = 'authenticated'
  );
```

### profile-photos

```sql
-- User boleh upload foto profil sendiri
create policy "profile-photos: user can upload own"
  on storage.objects for insert
  with check (
    bucket_id = 'profile-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Semua user login boleh baca foto profil
create policy "profile-photos: authenticated can read"
  on storage.objects for select
  using (
    bucket_id = 'profile-photos'
    and auth.role() = 'authenticated'
  );
```

### qris-assets

```sql
-- Semua user login boleh baca QRIS
create policy "qris-assets: authenticated can read"
  on storage.objects for select
  using (
    bucket_id = 'qris-assets'
    and auth.role() = 'authenticated'
  );

-- Admin boleh upload/update QRIS
create policy "qris-assets: admin can upload"
  on storage.objects for insert
  with check (
    bucket_id = 'qris-assets'
    and get_my_role() = 'admin'
  );

create policy "qris-assets: admin can update"
  on storage.objects for update
  using (
    bucket_id = 'qris-assets'
    and get_my_role() = 'admin'
  );
```

---

## Urutan Eksekusi di Supabase SQL Editor

1. Buat semua tabel (dari `DATABASE.md`)
2. Jalankan **Helper Function** `get_my_role()` di atas
3. Jalankan RLS per tabel sesuai urutan di atas
4. Buat Storage Buckets di Dashboard, lalu terapkan policies Storage
