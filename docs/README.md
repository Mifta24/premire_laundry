# Premier Laundry App - MVP Documentation

Dokumentasi ini dibuat untuk kebutuhan awal development aplikasi Premier Laundry berbasis Flutter dengan 3 role utama: Customer, Courier, dan Admin.

## Stack Final

- Mobile App: Flutter
- Backend: Supabase Free Plan
- Database: Supabase PostgreSQL
- Authentication: Supabase Auth
- Storage: Supabase Storage
- Notification: Firebase Cloud Messaging (FCM)
- Maps: OpenStreetMap + Geolocator + perhitungan jarak sederhana
- Payment Manual: QRIS statis + upload bukti pembayaran
- Payment Gateway: Xendit Test Mode / Sandbox

## File Dokumentasi

- `AGENTS.md` - pembagian role dan akses aplikasi
- `ALUR.md` - alur kerja aplikasi dari order sampai selesai
- `DATABASE.md` - rancangan database Supabase PostgreSQL

## Catatan MVP

Untuk versi awal, sistem dibuat sederhana terlebih dahulu. Fitur utama difokuskan pada order laundry, pembayaran manual, payment gateway testing, pengelolaan status, kurir, dan loyalty sederhana.
