import { cert, getApps, initializeApp } from "npm:firebase-admin@13.4.0/app";
import { getMessaging } from "npm:firebase-admin@13.4.0/messaging";
import { createClient } from "npm:@supabase/supabase-js@2";

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
  if (!authorization) {
    return jsonResponse({ error: "Authentication required" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    return jsonResponse(
      { error: "Supabase authentication is not configured" },
      500,
    );
  }

  try {
    const body: unknown = await request.json();
    if (typeof body !== "object" || body === null || Array.isArray(body)) {
      return jsonResponse({ error: "Invalid request body" }, 400);
    }
    const notificationId = (body as Record<string, unknown>).notificationId;
    if (typeof notificationId !== "string" || !notificationId.trim()) {
      return jsonResponse({ error: "notificationId is required" }, 400);
    }

    const bearerToken = authorization.replace(/^Bearer\s+/i, "").trim();
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${bearerToken}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userResult, error: userError } = await userClient.auth
      .getUser(bearerToken);
    if (userError || !userResult.user) {
      return jsonResponse({ error: "Invalid authentication" }, 401);
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
    if (!administrator) {
      return jsonResponse({ error: "Administrator access required" }, 403);
    }

    const { data: notification, error: notificationError } = await adminClient
      .from("notificacoes")
      .select("id,titulo,resumo,conteudo,categoria,tipo")
      .eq("id", notificationId.trim())
      .eq("tipo", "personalizada")
      .maybeSingle();
    if (notificationError) throw notificationError;
    if (!notification) {
      return jsonResponse({ error: "Custom notification not found" }, 404);
    }

    const { data: members, error: membersError } = await adminClient
      .from("membros")
      .select("usuario_id")
      .eq("ativo", true)
      .not("usuario_id", "is", null);
    if (membersError) throw membersError;

    const recipientIds = [
      ...new Set(
        ((members ?? []) as Array<{ usuario_id: string | null }>)
          .map((member: { usuario_id: string | null }) => member.usuario_id)
          .filter(
            (userId: string | null): userId is string =>
              typeof userId === "string",
          ),
      ),
    ];
    if (recipientIds.length > 0) {
      const { error: recipientError } = await adminClient
        .from("notificacoes_destinatarios")
        .upsert(
          recipientIds.map((userId) => ({
            notificacao_id: notification.id,
            usuario_id: userId,
            criado_em: new Date().toISOString(),
            lida_em: null,
          })),
          { onConflict: "notificacao_id,usuario_id" },
        );
      if (recipientError) throw recipientError;
    }

    const { error: publishError } = await adminClient
      .from("notificacoes")
      .update({ enviado_em: new Date().toISOString() })
      .eq("id", notification.id);
    if (publishError) throw publishError;

    let tokens: string[] = [];
    if (recipientIds.length > 0) {
      const { data: devices, error: devicesError } = await adminClient
        .from("device_tokens")
        .select("token")
        .eq("notifications_enabled", true)
        .in("user_id", recipientIds);
      if (devicesError) throw devicesError;
      tokens = [
        ...new Set(
          ((devices ?? []) as Array<{ token: string }>)
            .map((device: { token: string }) => device.token)
            .filter((token: string): token is string =>
              typeof token === "string" && token.length > 0
            ),
        ),
      ];
    }

    let pushSuccessCount = 0;
    let pushFailureCount = 0;
    let pushError: string | null = null;
    const serviceAccountValue = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    const expectedProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    if (tokens.length > 0) {
      if (!serviceAccountValue || !expectedProjectId) {
        pushError = "Firebase push is not configured";
      } else {
        const serviceAccount = JSON.parse(serviceAccountValue);
        if (
          serviceAccount.project_id !== expectedProjectId ||
          typeof serviceAccount.client_email !== "string" ||
          typeof serviceAccount.private_key !== "string"
        ) {
          pushError = "Firebase credentials are invalid";
        } else {
          const firebaseApp = getApps()[0] ?? initializeApp({
            credential: cert(serviceAccount),
            projectId: expectedProjectId,
          });
          for (let index = 0; index < tokens.length; index += 500) {
            const result = await getMessaging(firebaseApp).sendEachForMulticast({
              tokens: tokens.slice(index, index + 500),
              notification: {
                title: notification.titulo,
                body: notification.resumo || notification.conteudo,
              },
              data: {
                noticeId: notification.id,
                notificationId: notification.id,
              },
              android: {
                priority: "high",
                notification: { channelId: "agenda_alteracoes" },
              },
              apns: {
                payload: { aps: { sound: "default" } },
              },
            });
            pushSuccessCount += result.successCount;
            pushFailureCount += result.failureCount;
          }
        }
      }
    }

    return jsonResponse({
      sent: true,
      recipientCount: recipientIds.length,
      pushSuccessCount,
      pushFailureCount,
      pushError,
    });
  } catch (error) {
    console.error(
      "Failed to publish custom notification",
      error instanceof Error ? error.message : String(error),
    );
    return jsonResponse(
      { sent: false, error: "Unable to publish custom notification" },
      500,
    );
  }
});
