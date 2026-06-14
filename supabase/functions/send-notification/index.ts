import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { initializeApp, cert, getApps } from "npm:firebase-admin/app";
import { getMessaging } from "npm:firebase-admin/messaging";

// Inisialisasi Firebase Admin SDK (singleton)
function getFirebaseApp() {
  if (getApps().length > 0) return getApps()[0];

  const serviceAccount = JSON.parse(
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}"
  );

  return initializeApp({
    credential: cert(serviceAccount),
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    const { userId, title, body, data } = await req.json() as {
      userId: string;
      title: string;
      body: string;
      data?: Record<string, string>;
    };

    if (!userId || !title || !body) {
      return new Response(
        JSON.stringify({ error: "userId, title, dan body wajib diisi" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Ambil FCM tokens aktif milik user dari Supabase
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: devices, error } = await supabase
      .from("user_devices")
      .select("fcm_token")
      .eq("user_id", userId)
      .eq("is_active", true);

    if (error) throw error;
    if (!devices || devices.length === 0) {
      return new Response(
        JSON.stringify({ message: "Tidak ada device aktif untuk user ini" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const tokens: string[] = devices.map((d: { fcm_token: string }) => d.fcm_token);

    // Kirim notifikasi via Firebase Admin SDK
    getFirebaseApp();
    const messaging = getMessaging();

    const results = await Promise.allSettled(
      tokens.map((token) =>
        messaging.send({
          token,
          notification: { title, body },
          data: data ?? {},
          android: {
            notification: {
              channelId: "premier_laundry_channel",
              priority: "high",
            },
          },
        })
      )
    );

    // Hapus token yang sudah tidak valid (expired/unregistered)
    const invalidTokens: string[] = [];
    results.forEach((result, index) => {
      if (
        result.status === "rejected" &&
        (result.reason?.code === "messaging/invalid-registration-token" ||
          result.reason?.code === "messaging/registration-token-not-registered")
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length > 0) {
      await supabase
        .from("user_devices")
        .update({ is_active: false })
        .in("fcm_token", invalidTokens);
    }

    const successCount = results.filter((r) => r.status === "fulfilled").length;

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        total: tokens.length,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("send-notification error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
