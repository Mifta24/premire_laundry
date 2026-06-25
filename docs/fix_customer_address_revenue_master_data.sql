-- Jalankan di Supabase SQL Editor untuk memperbaiki:
-- 1) alamat customer yang tidak bisa "dihapus" karena pernah dipakai order,
-- 2) layanan/ongkir dobel akibat setup seed dijalankan berulang,
-- 3) payment paid lama yang belum punya paid_at sehingga tidak masuk grafik.

begin;

-- Soft delete alamat: order lama tetap bisa membaca alamat historis,
-- sedangkan daftar alamat customer hanya menampilkan alamat aktif.
alter table addresses add column if not exists deleted_at timestamptz;
create index if not exists idx_addresses_user_active
  on addresses(user_id)
  where deleted_at is null;

-- Payment lama yang sudah paid tapi paid_at kosong tetap dihitung pendapatan.
update payments
set paid_at = coalesce(updated_at, created_at, now())
where status = 'paid'
  and paid_at is null;

-- Gabungkan layanan laundry yang identitas bisnisnya sama.
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

create unique index if not exists uniq_laundry_services_business_identity
  on laundry_services (
    lower(btrim(name)),
    service_type,
    price,
    lower(btrim(unit))
  );

-- Hapus ongkir yang benar-benar identik.
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

create unique index if not exists uniq_delivery_fees_business_identity
  on delivery_fees (
    lower(btrim(name)),
    min_distance_km,
    coalesce(max_distance_km, -1),
    fee
  );

commit;
