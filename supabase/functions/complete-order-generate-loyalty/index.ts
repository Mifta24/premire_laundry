import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const { orderId } = await req.json() as { orderId: string };

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // Ambil data order
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, customer_id, status")
      .eq("id", orderId)
      .single();

    if (orderError || !order) throw new Error("Order tidak ditemukan");
    if (order.status === "completed") {
      return new Response(
        JSON.stringify({ message: "Order sudah selesai sebelumnya" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Update status order ke completed
    await supabase
      .from("orders")
      .update({ status: "completed" })
      .eq("id", orderId);

    // Proses loyalty points
    const customerId = order.customer_id;

    const { data: loyalty } = await supabase
      .from("loyalty_points")
      .select("*")
      .eq("user_id", customerId)
      .maybeSingle();

    let currentCycle = (loyalty?.current_cycle_count ?? 0) + 1;
    const totalCompleted = (loyalty?.total_completed_orders ?? 0) + 1;
    let totalVouchers = loyalty?.total_vouchers_earned ?? 0;
    let voucherGenerated = false;

    // Setiap 10 order selesai → generate voucher gratis
    if (currentCycle >= 10) {
      currentCycle = 0;
      totalVouchers += 1;
      voucherGenerated = true;

      const voucherCode = `PL-${customerId.substring(0, 4).toUpperCase()}-${Date.now()}`;
      const expiredAt = new Date();
      expiredAt.setMonth(expiredAt.getMonth() + 3); // berlaku 3 bulan

      await supabase.from("vouchers").insert({
        user_id: customerId,
        code: voucherCode,
        type: "free_laundry",
        discount_percent: 100,
        status: "active",
        expired_at: expiredAt.toISOString(),
      });
    }

    // Upsert loyalty points
    await supabase.from("loyalty_points").upsert(
      {
        user_id: customerId,
        total_completed_orders: totalCompleted,
        current_cycle_count: currentCycle,
        total_vouchers_earned: totalVouchers,
      },
      { onConflict: "user_id" }
    );

    // Kirim notifikasi ke customer
    const notifBody = voucherGenerated
      ? "Selamat! Anda mendapatkan voucher gratis 1x cuci 🎉"
      : `Laundry Anda selesai! Progress loyalti: ${currentCycle}/10`;

    await fetch(
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/send-notification`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
        },
        body: JSON.stringify({
          userId: customerId,
          title: "Laundry Selesai ✅",
          body: notifBody,
          data: { orderId, type: "order_completed" },
        }),
      }
    );

    return new Response(
      JSON.stringify({
        success: true,
        loyaltyProgress: `${currentCycle}/10`,
        voucherGenerated,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("complete-order error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
