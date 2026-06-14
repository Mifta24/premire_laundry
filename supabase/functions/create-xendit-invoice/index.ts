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
    const { orderId, amount, customerName, customerEmail } = await req.json() as {
      orderId: string;
      amount: number;
      customerName: string;
      customerEmail: string;
    };

    const xenditSecretKey = Deno.env.get("XENDIT_SECRET_KEY");
    if (!xenditSecretKey) throw new Error("XENDIT_SECRET_KEY belum diset");

    // Buat invoice di Xendit
    const xenditResponse = await fetch("https://api.xendit.co/v2/invoices", {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(xenditSecretKey + ":")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        external_id: orderId,
        amount,
        payer_email: customerEmail,
        description: `Pembayaran Order Premier Laundry #${orderId}`,
        customer: { given_names: customerName, email: customerEmail },
        currency: "IDR",
        success_redirect_url: `${Deno.env.get("APP_SCHEME") ?? "premierlaundry"}://payment-success`,
        failure_redirect_url: `${Deno.env.get("APP_SCHEME") ?? "premierlaundry"}://payment-failed`,
      }),
    });

    if (!xenditResponse.ok) {
      const err = await xenditResponse.json();
      throw new Error(`Xendit error: ${JSON.stringify(err)}`);
    }

    const invoice = await xenditResponse.json();

    // Simpan data payment ke Supabase
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: orderData } = await supabase
      .from("orders")
      .select("customer_id")
      .eq("id", orderId)
      .single();

    await supabase.from("payments").upsert({
      order_id: orderId,
      customer_id: orderData?.customer_id,
      method: "xendit",
      provider: "xendit",
      amount,
      status: "pending",
      provider_reference: invoice.id,
      payment_url: invoice.invoice_url,
    }, { onConflict: "order_id" });

    return new Response(
      JSON.stringify({
        invoiceId: invoice.id,
        invoiceUrl: invoice.invoice_url,
        expiryDate: invoice.expiry_date,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("create-xendit-invoice error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
