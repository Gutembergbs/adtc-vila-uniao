import { serve } from "https://deno.land/x/supabase@2.44.2/functions/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);

serve(async (req) => {
  const payload = await req.json();
  const { record, type } = payload; // payload from trigger

  // Only handle INSERT on messages table (adjust as needed)
  if (type !== "INSERT" || record.table !== "messages") {
    return new Response(JSON.stringify({ status: "ignored" }), { status: 200 });
  }

  const newMessage = record.new;
  const userId = newMessage.user_id;

  // Get device tokens for the user
  const { data: tokens, error } = await supabase
    .from("device_tokens")
    .select("token, platform")
    .eq("user_id", userId);

  if (error) {
    console.error("Failed to fetch tokens", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  for (const { token, platform } of tokens) {
    const body = {
      to: token,
      notification: {
        title: "Nova mensagem",
        body: newMessage.content ?? "Você tem uma nova mensagem",
      },
    };
    const fcmUrl = "https://fcm.googleapis.com/fcm/send";
    // You need to set your server key as an env var in Supabase Functions settings
    const serverKey = Deno.env.get("FCM_SERVER_KEY");
    if (!serverKey) continue;
    await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${serverKey}`,
      },
      body: JSON.stringify(body),
    });
  }

  return new Response(JSON.stringify({ status: "sent" }), { status: 200 });
});
