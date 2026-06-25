# Tes Payment Gateway Xendit

Dokumen ini menjelaskan cara melakukan pembayaran menggunakan payment gateway Xendit di aplikasi Premier Laundry, khususnya untuk mode testing.

Payment gateway dipakai saat customer memilih metode pembayaran **Xendit**. Aplikasi tidak menyimpan secret key Xendit di Flutter. Flutter hanya meminta invoice ke Supabase Edge Function, lalu membuka halaman pembayaran dari Xendit.

## Prasyarat

Sebelum dites, pastikan bagian berikut sudah aktif:

1. Supabase Edge Function `create-xendit-invoice` sudah dideploy.
2. Supabase Edge Function `xendit-webhook` sudah dideploy dengan `--no-verify-jwt`.
3. Secret `XENDIT_SECRET_KEY` sudah diset di Supabase.
4. Secret `XENDIT_WEBHOOK_TOKEN` sudah diset jika webhook token dipakai.
5. URL webhook sudah didaftarkan di dashboard Xendit:

```text
https://<PROJECT_REF>.supabase.co/functions/v1/xendit-webhook
```

Untuk project ini, script deploy ada di:

```text
supabase/deploy.sh
```

## Alur Pembayaran di Aplikasi

1. Customer membuat order.
2. Customer memilih metode pembayaran **Xendit**.
3. Flutter memanggil Edge Function `create-xendit-invoice` dengan data:
   - `orderId`
   - `amount`
   - `customerName`
   - `customerEmail`
4. Edge Function membuat invoice ke Xendit Test Mode.
5. Xendit mengembalikan `invoice_url`.
6. Flutter membuka `invoice_url` di browser atau in-app webview.
7. Customer memilih metode pembayaran di halaman Xendit.
8. Setelah pembayaran berhasil, Xendit mengirim webhook ke `xendit-webhook`.
9. Webhook mengubah:
   - `payments.status` menjadi `paid`
   - `orders.payment_status` menjadi `paid`
   - `orders.status` menjadi `paid`
10. Aplikasi diarahkan kembali ke detail order lewat deep link:

```text
premierlaundry://payment-success?orderId=<ORDER_ID>
```

Jika pembayaran gagal, redirect yang dipakai:

```text
premierlaundry://payment-failed?orderId=<ORDER_ID>
```

## Cara Tes dari Aplikasi

1. Login sebagai customer.
2. Buat pesanan baru.
3. Untuk order satuan, pilih metode pembayaran **Xendit** saat membuat order.
4. Untuk order kiloan, tunggu admin input berat dan mengubah status menjadi `waiting_payment`, lalu buka detail order dan pilih pembayaran.
5. Setelah halaman Xendit terbuka, pilih salah satu metode pembayaran test di bawah.
6. Selesaikan simulasi pembayaran.
7. Kembali ke aplikasi.
8. Cek detail order. Status pembayaran seharusnya berubah menjadi `paid` setelah webhook diterima.

## Data Test Xendit

### Kartu Kredit/Debit

| Field | Value |
| --- | --- |
| Nomor kartu | `4000 0000 0000 0002` |
| Expiry | `12/25` atau tanggal masa depan apa saja |
| CVV | `123` |
| Nama | Nama apa saja |

### e-Wallet OVO / DANA / ShopeePay

| Nomor HP | Hasil |
| --- | --- |
| `+6281234567890` | Sukses |
| `+6281234567891` | Gagal |

### Virtual Account

1. Pilih bank apa saja di halaman invoice Xendit.
2. Lanjutkan sampai muncul instruksi pembayaran.
3. Di Test Mode, klik tombol bayar atau ikuti simulator yang tersedia di halaman Xendit.
4. Xendit akan mensimulasikan pembayaran sukses.

## Status yang Harus Dicek

Setelah pembayaran berhasil, cek data berikut di Supabase:

### Tabel `payments`

```text
order_id = <ORDER_ID>
method = xendit
provider = xendit
status = paid
provider_reference = <XENDIT_INVOICE_ID>
payment_url = <XENDIT_INVOICE_URL>
paid_at tidak null
```

### Tabel `orders`

```text
id = <ORDER_ID>
payment_status = paid
status = paid
```

## Jika Status Belum Berubah

Cek hal berikut:

1. Pastikan invoice di Xendit benar-benar sudah berstatus paid.
2. Pastikan URL webhook Xendit mengarah ke:

```text
https://<PROJECT_REF>.supabase.co/functions/v1/xendit-webhook
```

3. Pastikan token webhook di dashboard Xendit sama dengan secret `XENDIT_WEBHOOK_TOKEN`.
4. Cek log function `xendit-webhook` di Supabase.
5. Pastikan payload webhook memiliki `external_id` yang sama dengan `orderId`.
6. Pastikan record `payments` sudah dibuat oleh `create-xendit-invoice`.

## Catatan Penting

- Jangan memasukkan `XENDIT_SECRET_KEY` di Flutter.
- Secret key hanya boleh disimpan di Supabase Edge Function secrets.
- Flutter hanya menerima `invoiceUrl`.
- `external_id` di Xendit diisi dengan `orderId`, jadi webhook tahu order mana yang harus diupdate.
- Jika Edge Function diubah, function harus dideploy ulang. Hot reload Flutter tidak akan mengubah kode Edge Function.
