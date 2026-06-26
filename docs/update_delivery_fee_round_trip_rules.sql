-- Update aturan biaya jemput & antar untuk database yang sudah pernah
-- di-seed dengan tarif ongkir lama.
--
-- Aturan aplikasi:
--   biaya jemput & antar = ceil(jarak_km) x tarif_per_km x 2
--
-- Jalankan di Supabase SQL Editor setelah deploy perubahan Flutter.

begin;

drop index if exists uniq_delivery_fees_business_identity;

delete from delivery_fees
where (min_distance_km = 0 and max_distance_km = 2)
   or (min_distance_km = 2 and max_distance_km = 5)
   or (min_distance_km = 5 and max_distance_km = 8)
   or (min_distance_km = 8 and max_distance_km is null);

insert into delivery_fees (name, min_distance_km, max_distance_km, fee, is_active)
values
  ('0 - 2 km',  0, 2,    5000, true),
  ('2 - 5 km',  2, 5,    4000, true),
  ('5 - 8 km',  5, 8,    3500, true),
  ('> 8 km',    8, null, 3000, true);

create unique index uniq_delivery_fees_business_identity
  on delivery_fees (lower(btrim(name)), min_distance_km, coalesce(max_distance_km, -1));

commit;
