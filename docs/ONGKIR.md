# Dokumentasi Biaya Jemput & Antar

Dokumen ini menjelaskan aturan biaya jemput dan antar Premier Laundry.
Untuk MVP, sistem tidak memakai konsep ekspedisi penuh seperti berat
volumetrik. Biaya layanan laundry dan biaya jemput-antar dihitung terpisah.

## Ringkasan Aturan

Total pesanan dihitung dengan rumus:

```text
total = subtotal laundry + biaya jemput & antar - diskon
```

Untuk laundry kiloan:

```text
subtotal laundry = berat tagihan x tarif layanan per kg
```

Untuk jemput dan antar:

```text
biaya jemput & antar = ceil(jarak_km) x tarif_per_km x 2
```

Faktor `x 2` dipakai karena layanan mencakup dua perjalanan:

1. Jemput pakaian dari customer.
2. Antar pakaian kembali ke customer.

## Perhitungan Jarak

Jarak dihitung dari koordinat toko ke koordinat alamat customer menggunakan
rumus Haversine. Hasil ini adalah estimasi jarak garis lurus, bukan rute jalan
real-time seperti Google Maps.

Jika alamat belum memiliki latitude dan longitude, biaya jemput & antar tidak
dapat dihitung akurat. Customer harus memilih titik lokasi dari pencarian,
lokasi saat ini, atau tap pada peta saat menambahkan alamat.

## Tarif Per Kilometer

Tarif tersimpan di tabel `delivery_fees` dengan arti:

```text
fee = tarif per kilometer
```

Tarif default:

| Rentang Jarak | Tarif per Km |
| --- | ---: |
| 0 - 2 km | Rp5.000 |
| 2 - 5 km | Rp4.000 |
| 5 - 8 km | Rp3.500 |
| > 8 km | Rp3.000 |

Contoh:

```text
jarak = 5.2 km
ceil(jarak) = 6 km
tarif = Rp3.500/km
biaya jemput & antar = 6 x 3.500 x 2 = Rp42.000
```

## Berat Laundry Kiloan

Berat yang disimpan di `order_items.weight_kg` adalah berat aktual hasil
timbang toko. Untuk tagihan, sistem membulatkan berat ke atas per 0.5 kg
dengan minimum 1 kg.

Contoh:

| Berat Aktual | Berat Tagihan |
| ---: | ---: |
| 0.7 kg | 1.0 kg |
| 1.1 kg | 1.5 kg |
| 1.6 kg | 2.0 kg |
| 2.0 kg | 2.0 kg |

Berat volumetrik tidak dipakai karena lebih cocok untuk ekspedisi paket atau
kargo, bukan laundry lokal.

## Dampak di UI

Label customer dan admin menggunakan istilah:

```text
Biaya Jemput & Antar
```

Halaman detail order menampilkan berat kiloan sebagai:

```text
Aktual x.x kg, tagihan y.y kg
```

Ini membuat customer dan admin bisa melihat perbedaan berat timbang aktual dan
berat yang ditagihkan.

## Update Database Live

Untuk database yang sudah pernah di-seed dengan tarif lama, jalankan:

```text
docs/update_delivery_fee_round_trip_rules.sql
```

SQL tersebut akan mengganti tarif lama, membuat rentang jarak tidak dobel, dan
mengubah unique index `delivery_fees` agar identitas bisnisnya berdasarkan nama
dan rentang jarak.
