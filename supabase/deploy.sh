#!/bin/bash
# Script deploy semua Edge Functions Premier Laundry
# Jalankan: bash supabase/deploy.sh

PROJECT_REF="quszopbpzmeqehrbpyvl"

echo "=== Login Supabase CLI ==="
supabase login

echo ""
echo "=== Link ke project ==="
supabase link --project-ref $PROJECT_REF

echo ""
echo "=== Set Secrets ==="
echo "Masukkan Firebase Service Account JSON (paste satu baris, tekan Enter):"
read -r FIREBASE_SA
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$FIREBASE_SA"

echo "Masukkan Xendit Secret Key:"
read -r XENDIT_KEY
supabase secrets set XENDIT_SECRET_KEY="$XENDIT_KEY"

echo "Masukkan Xendit Webhook Token:"
read -r XENDIT_TOKEN
supabase secrets set XENDIT_WEBHOOK_TOKEN="$XENDIT_TOKEN"

echo ""
echo "=== Deploy Edge Functions ==="
supabase functions deploy send-notification --no-verify-jwt
supabase functions deploy create-xendit-invoice
supabase functions deploy xendit-webhook --no-verify-jwt
supabase functions deploy complete-order-generate-loyalty

echo ""
echo "✅ Deploy selesai!"
echo ""
echo "URL Edge Functions:"
echo "  send-notification:               https://$PROJECT_REF.supabase.co/functions/v1/send-notification"
echo "  create-xendit-invoice:           https://$PROJECT_REF.supabase.co/functions/v1/create-xendit-invoice"
echo "  xendit-webhook:                  https://$PROJECT_REF.supabase.co/functions/v1/xendit-webhook"
echo "  complete-order-generate-loyalty: https://$PROJECT_REF.supabase.co/functions/v1/complete-order-generate-loyalty"
echo ""
echo "⚠️  Daftarkan URL xendit-webhook ke Xendit Dashboard > Settings > Webhooks"
