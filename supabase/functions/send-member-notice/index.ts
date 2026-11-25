import { createClient } from "npm:@supabase/supabase-js@2";
import { cert, getApps, initializeApp } from "npm:firebase-admin@13.4.0/app";
import { getMessaging } from "npm:firebase-admin@13.4.0/messaging";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return Response.json(body, { status, headers: corsHeaders });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  const token = authorization?.replace(/^Bearer\s+/i, "");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!token || !supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: "Server authentication is not configured" }, 500);
  }

  try {
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userResult, error: userError } = await userClient.auth.getUser(
      token,
    );
    if (userError || !userResult.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: administrator, error: administratorError } =
      await adminClient
        .from("administradores")
        .select("usuario_id")
        .eq("usuario_id", userResult.user.id)
        .maybeSingle();
    if (administratorError) throw administratorError;
    if (!administrator) return jsonResponse({ error: "Forbidden" }, 403);

    const payload = await request.json();
    const noticeId = String(payload.noticeId ?? "").trim();
    if (!noticeId) {
      return jsonResponse({ error: "noticeId is required" }, 400);
    }

    const { data: notice, error: noticeError } = await adminClient
      .from("avisos_membros")
      .select("id,membro_id,titulo,conteudo")
      .eq("id", noticeId)
      .maybeSingle();
    if (noticeError) throw noticeError;
    if (!notice) return jsonResponse({ error: "Notice not found" }, 404);

    const { data: member, error: memberError } = await adminClient
      .from("membros")
      .select("usuario_id,ativo")
      .eq("id", notice.membro_id)
      .maybeSingle();
    if (memberError) throw memberError;
    if (!member?.ativo || !member.usuario_id) {
      return jsonResponse({
        sent: false,
        reason: "member_has_no_active_account",
      });
    }

    const { data: devices, error: devicesError } = await adminClient
      .from("device_tokens")
      .select("token")
      .eq("user_id", member.usuario_id);
    if (devicesError) throw devicesError;
    const tokens = [...new Set((devices ?? []).map((device) => device.token))];
    if (tokens.length === 0) {
      return jsonResponse({ sent: false, reason: "no_registered_devices" });
    }

    const serviceAccountValue = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    const expectedProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    if (!serviceAccountValue || !expectedProjectId) {
      return jsonResponse({ error: "Firebase push is not configured" }, 500);
    }
    const serviceAccount = JSON.parse(serviceAccountValue);
    if (
      serviceAccount.project_id !== expectedProjectId ||
      typeof serviceAccount.client_email !== "string" ||
      typeof serviceAccount.private_key !== "string"
    ) {
      return jsonResponse({ error: "Firebase credentials are invalid" }, 500);
    }
    const firebaseApp = getApps()[0] ?? initializeApp({
      credential: cert(serviceAccount),
      projectId: expectedProjectId,
    });

    let successCount = 0;
    for (let index = 0; index < tokens.length; index += 500) {
      const batch = tokens.slice(index, index + 500);
      const result = await getMessaging(firebaseApp).sendEachForMulticast({
        tokens: batch,
        notification: {
          title: "Novo aviso da congregação",
          body: "Abra o app para consultar seu aviso.",
        },
        data: {
          noticeId: notice.id,
        },
        android: {
          priority: "high",
          notification: { channelId: "agenda_alteracoes" },
        },
        apns: {
          payload: { aps: { sound: "default" } },
        },
      });
      successCount += result.successCount;
    }
    return jsonResponse({ sent: successCount > 0, successCount });
  } catch (error) {
    console.error(
      "Failed to send member notice push",
      error instanceof Error ? error.message : String(error),
    );
    return jsonResponse({ error: "Unable to send member notification" }, 500);
  }
});
