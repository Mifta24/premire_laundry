-- Fix akses halaman kurir:
-- Jalankan di Supabase SQL Editor untuk mengizinkan kurir membaca nama
-- customer dan koordinat alamat hanya pada order yang ditugaskan kepadanya.

drop policy if exists "profiles: courier can read assigned customers" on profiles;
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

drop policy if exists "addresses: courier can read assigned order addresses" on addresses;
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
