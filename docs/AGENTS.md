# AGENTS.md

## Overview

Aplikasi Premier Laundry menggunakan 3 role utama dalam satu aplikasi Flutter:

1. Customer / User
2. Courier / Kurir
3. Admin

Setelah login, aplikasi membaca role user dari tabel `profiles`, lalu mengarahkan user ke dashboard sesuai role.

```text
Login
↓
Supabase Auth
↓
Ambil profile user
↓
Cek role
↓
Redirect dashboard berdasarkan role
```

---

## 1. Customer / User

### Tujuan
Customer menggunakan aplikasi untuk membuat pesanan laundry, memilih alamat, melakukan pembayaran, dan melihat status laundry.

### Fitur Minimal

- Register dan login
- Kelola profil sederhana
- Tambah dan pilih alamat
- Pilih titik lokasi menggunakan OpenStreetMap
- Buat order laundry
- Pilih jenis layanan:
  - Laundry kiloan
  - Laundry satuan
- Tambah catatan pakaian
- Melihat estimasi ongkir
- Melakukan pembayaran:
  - QRIS statis manual
  - Upload bukti pembayaran
  - Xendit Test Mode sebagai alternatif
- Melihat status laundry
- Melihat riwayat order
- Melihat voucher loyalty

### Batasan Akses

- Customer hanya boleh melihat order miliknya sendiri.
- Customer tidak boleh melihat data order customer lain.
- Customer tidak boleh mengubah status laundry secara langsung.

---

## 2. Courier / Kurir

### Tujuan
Kurir menggunakan aplikasi untuk melihat tugas jemput/antar dan mengupdate status perjalanan.

### Fitur Minimal

- Login
- Melihat daftar tugas jemput
- Melihat daftar tugas antar
- Melihat detail alamat customer
- Membuka rute menggunakan aplikasi Maps eksternal
- Update status tugas:
  - Menuju lokasi jemput
  - Pakaian sudah diambil
  - Menuju lokasi antar
  - Pakaian sudah diterima customer

### Batasan Akses

- Kurir hanya boleh melihat tugas yang diberikan kepadanya.
- Kurir tidak boleh mengubah harga order.
- Kurir tidak boleh validasi pembayaran.
- Kurir tidak boleh mengelola layanan laundry.

---

## 3. Admin

### Tujuan
Admin mengelola order, pembayaran, layanan, harga, berat laundry kiloan, dan assignment kurir.

### Fitur Minimal

- Login
- Melihat semua order
- Melihat detail order
- Mengelola layanan laundry
- Mengelola harga laundry kiloan/satuan
- Mengatur ongkir sederhana
- Assign kurir untuk jemput/antar
- Input berat laundry kiloan
- Generate tagihan laundry kiloan
- Validasi bukti pembayaran manual
- Update status laundry
- Melihat laporan sederhana

### Status yang Bisa Diubah Admin

- Order dibuat
- Menunggu jemput
- Pakaian diterima toko
- Menunggu pembayaran
- Pembayaran valid
- Sedang dicuci
- Sedang disetrika
- Siap diantar
- Selesai
- Dibatalkan

### Batasan Akses

- Admin memiliki akses penuh ke order dan master data.
- Admin bertanggung jawab atas validasi pembayaran manual.
- Admin bertanggung jawab atas input berat laundry kiloan.

---

## Role Value

Gunakan value role berikut pada tabel `profiles`:

```text
customer
courier
admin
```

---

## Recommended Flutter Routing

```text
LoginPage
↓
RoleCheckerPage
↓
CustomerHomePage / CourierHomePage / AdminHomePage
```

---

## Security Notes

Walaupun role sudah dipisah di UI Flutter, keamanan utama tetap harus diatur di Supabase menggunakan Row Level Security (RLS).

Minimal RLS:

- Customer hanya dapat membaca order miliknya.
- Courier hanya dapat membaca task miliknya.
- Admin dapat membaca dan mengubah semua order.
