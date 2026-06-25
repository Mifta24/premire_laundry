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

-- Sinkronkan daftar harga layanan terbaru.
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
