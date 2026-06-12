# ALUR.md

## Overview

Dokumen ini menjelaskan alur aplikasi Premier Laundry versi MVP. Sistem memiliki 3 role: Customer, Courier, dan Admin.

Payment utama menggunakan QRIS statis/manual dan upload bukti pembayaran. Payment gateway Xendit Test Mode digunakan sebagai alternatif untuk uji coba.

---

## 1. Alur Login Berdasarkan Role

```text
User membuka aplikasi
↓
Login / Register
↓
Supabase Auth memvalidasi akun
↓
Aplikasi mengambil data profile dari tabel profiles
↓
Sistem membaca role
↓
Redirect:
- customer → Customer Dashboard
- courier → Courier Dashboard
- admin → Admin Dashboard
```

---

## 2. Alur Customer Membuat Order Laundry Satuan

```text
Customer login
↓
Pilih layanan laundry satuan
↓
Pilih item laundry dan jumlah
↓
Input catatan pakaian jika perlu
↓
Pilih alamat dan titik lokasi
↓
Sistem hitung ongkir sederhana
↓
Total harga langsung muncul
↓
Customer memilih metode pembayaran
↓
QRIS Manual / Xendit Test Mode
↓
Pembayaran dikonfirmasi
↓
Admin assign kurir
↓
Kurir jemput pakaian
↓
Laundry diproses
↓
Kurir antar pakaian
↓
Order selesai
```

---

## 3. Alur Customer Membuat Order Laundry Kiloan

```text
Customer login
↓
Pilih laundry kiloan
↓
Input catatan pakaian jika perlu
↓
Pilih alamat dan titik lokasi
↓
Sistem hitung ongkir sederhana
↓
Customer submit order
↓
Status: waiting_pickup
↓
Admin assign kurir jemput
↓
Kurir mengambil pakaian
↓
Pakaian diterima toko
↓
Admin timbang pakaian
↓
Admin input berat asli
↓
Sistem generate tagihan
↓
Customer menerima notifikasi tagihan
↓
Customer memilih pembayaran
↓
QRIS Manual / Xendit Test Mode
↓
Pembayaran dikonfirmasi
↓
Laundry diproses
↓
Kurir antar pakaian
↓
Order selesai
```

---

## 4. Alur QRIS Manual

```text
Customer memilih QRIS Manual
↓
Aplikasi menampilkan QRIS statis toko
↓
Customer membayar dari e-wallet/mobile banking
↓
Customer upload bukti pembayaran
↓
Status payment: waiting_verification
↓
Admin membuka menu pembayaran
↓
Admin cek bukti pembayaran dan mutasi rekening
↓
Admin klik Valid / Tolak
↓
Jika valid:
- payment status = paid
- order lanjut diproses
↓
Jika ditolak:
- payment status = rejected
- customer upload ulang bukti pembayaran
```

---

## 5. Alur Xendit Test Mode

```text
Customer memilih pembayaran Xendit
↓
Flutter memanggil Supabase Edge Function create-xendit-invoice
↓
Edge Function membuat invoice ke Xendit Test Mode
↓
Xendit mengembalikan invoice_url
↓
Flutter membuka invoice_url
↓
Customer melakukan simulasi pembayaran
↓
Xendit mengirim webhook/callback ke Supabase Edge Function
↓
Edge Function update tabel payments
↓
Jika paid:
- payment status = paid
- order lanjut diproses
```

Catatan:

- Secret key Xendit tidak boleh disimpan di Flutter.
- Secret key harus disimpan di Supabase Edge Function secrets.
- Flutter hanya menerima payment URL/invoice URL.

---

## 6. Alur Kurir Jemput

```text
Admin assign kurir untuk order
↓
Task muncul di aplikasi kurir
↓
Kurir buka detail tugas
↓
Kurir klik Buka Maps
↓
Aplikasi membuka rute ke lokasi customer
↓
Kurir klik Menuju Lokasi
↓
Customer mendapat notifikasi
↓
Kurir mengambil pakaian
↓
Kurir klik Pakaian Diambil
↓
Order status berubah
```

---

## 7. Alur Kurir Antar

```text
Admin mengubah status order menjadi siap diantar
↓
Admin assign kurir antar
↓
Task antar muncul di aplikasi kurir
↓
Kurir buka rute ke alamat customer
↓
Kurir klik Menuju Lokasi Antar
↓
Customer mendapat notifikasi
↓
Pakaian diterima customer
↓
Kurir klik Selesai
↓
Order status = completed
↓
Loyalty customer bertambah
```

---

## 8. Alur Notifikasi FCM

```text
Flutter mengambil FCM token
↓
Token disimpan ke tabel user_devices
↓
Ada perubahan status penting
↓
Supabase Edge Function dipanggil
↓
Edge Function mengirim notifikasi ke Firebase FCM
↓
User menerima push notification
```

Contoh notifikasi:

- Kurir sedang menuju lokasi jemput.
- Tagihan laundry kamu sudah tersedia.
- Pembayaran berhasil diverifikasi.
- Laundry sedang diproses.
- Laundry selesai dan siap diantar.

---

## 9. Alur Loyalty

```text
Order selesai
↓
Sistem menambah 1 poin loyalty
↓
Jika total 10 order selesai
↓
Sistem membuat voucher gratis 1x cuci
↓
Customer dapat menggunakan voucher untuk order berikutnya
```

Catatan:

- Voucher hanya berlaku untuk layanan laundry.
- Ongkir tetap dibayar customer.
