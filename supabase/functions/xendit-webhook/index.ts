import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  try {
    // Validasi webhook token dari Xendit
    const webhookToken = req.headers.get("x-callback-token");
    const expectedToken = Deno.env.get("XENDIT_WEBHOOK_TOKEN");

    if (expectedToken && webhookToken !== expectedToken) {
      return new Response(JSON.stringify({ error: "Token tidak valid" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload = await req.json();
    const { external_id, status, id: xenditId } = payload;

    // external_id = orderId yang kita set saat buat invoice
    const orderId = external_id;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    if (status === "PAID" || status === "SETTLED") {
      // Update payment status
      await supabase
        .from("payments")
        .update({
          status: "paid",
          provider_reference: xenditId,
          paid_at: new Date().toISOString(),
        })
        .eq("order_id", orderId);

      // Update order status
      await supabase
        .from("orders")
        .update({
          payment_status: "paid",
          status: "paid",
        })
        .eq("id", orderId);

      // Catat status history
      const { data: order } = await supabase
        .from("orders")
        .select("customer_id")
        .eq("id", orderId)
        .single();

      await supabase.from("order_status_histories").insert({
        order_id: orderId,
        status: "paid",
        changed_by: order?.customer_id,
        note: "Pembayaran dikonfirmasi via Xendit",
      });

      // Kirim notifikasi ke customer
      if (order?.customer_id) {
        await fetch(
          `${Deno.env.get("SUPABASE_URL")}/functions/v1/send-notification`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
            },
            body: JSON.stringify({
              userId: order.customer_id,
              title: "Pembayaran Berhasil ✅",
              body: "Pembayaran Anda telah dikonfirmasi. Laundry segera diproses!",
              data: { orderId, type: "payment_success" },
            }),
          }
        );
      }
    } else if (status === "EXPIRED") {
      await supabase
        .from("payments")
        .update({ status: "expired" })
        .eq("order_id", orderId);
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("xendit-webhook error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
