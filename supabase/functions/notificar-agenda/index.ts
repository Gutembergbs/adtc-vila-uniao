import { cert, getApps, initializeApp } from "npm:firebase-admin@13.4.0/app";
import { getMessaging } from "npm:firebase-admin@13.4.0/messaging";
import { createClient } from "npm:@supabase/supabase-js@2";

const notificationTypes = {
  added: {
    title: "Novo evento na agenda",
    body: (eventTitle: string) => `${eventTitle} foi adicionado.`,
  },
  changed: {
    title: "Agenda atualizada",
    body: (eventTitle: string) => `${eventTitle} teve uma alteração.`,
  },
  cancelled: {
    title: "Evento cancelado",
    body: (eventTitle: string) => `${eventTitle} foi cancelado.`,
  },
  event: {
    title: "Evento da agenda",
    body: (eventTitle: string) => eventTitle,
  },
};

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
    return new Response("Method not allowed", {
      status: 405,
      headers: corsHeaders,
    });
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
    const requestBody: unknown = await request.json();
    if (
      typeof requestBody !== "object" ||
      requestBody === null ||
      Array.isArray(requestBody)
    ) {
      return jsonResponse({ error: "Invalid request body" }, 400);
    }

    const payload = requestBody as Record<string, unknown>;
    const eventId = typeof payload.eventId === "string"
      ? payload.eventId.trim()
      : "";
    const requestedType = payload.type;
    if (
      !eventId ||
      typeof requestedType !== "string" ||
      !Object.hasOwn(notificationTypes, requestedType)
    ) {
      return jsonResponse(
        { error: "A valid eventId and notification type are required" },
        400,
      );
    }
    const type = requestedType as keyof typeof notificationTypes;

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const bearerToken = authorization.replace(/^Bearer\s+/i, "").trim();
    const { data: userData, error: userError } = await supabase.auth.getUser(
      bearerToken,
    );
    if (userError || !userData.user) {
      return jsonResponse({ error: "Invalid authentication" }, 401);
    }

    const { data: administrator, error: administratorError } = await supabase
      .from("administradores")
      .select("usuario_id")
      .eq("usuario_id", userData.user.id)
      .maybeSingle();
    if (administratorError) {
      console.error("Could not verify agenda administrator", administratorError);
      return jsonResponse(
        { error: "Could not verify administrator access" },
        500,
      );
    }
    if (!administrator) {
      return jsonResponse({ error: "Administrator access required" }, 403);
    }

    const { data: event, error: eventError } = await supabase
      .from("eventos_agenda")
      .select("id, titulo")
      .eq("id", eventId)
      .maybeSingle();
    if (eventError) {
      console.error("Could not load agenda event", eventError);
      return jsonResponse({ error: "Could not load agenda event" }, 500);
    }
    if (!event) {
      return jsonResponse({ error: "Agenda event not found" }, 404);
    }

    const notification = notificationTypes[type];
    const notificationBody = notification.body(event.titulo);
    const adminSupabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: inboxNotification, error: inboxNotificationError } =
      await adminSupabase
        .from("notificacoes")
        .insert({
          tipo: "evento",
          titulo: notification.title,
          resumo: event.titulo,
          conteudo: notificationBody,
          categoria: "Agenda",
          evento_id: event.id,
          criado_por: userData.user.id,
          enviado_em: new Date().toISOString(),
        })
        .select("id")
        .single();
    if (inboxNotificationError) {
      console.error("Could not save agenda inbox notification", inboxNotificationError);
      return jsonResponse(
        { sent: false, error: "Could not save agenda notification" },
        500,
      );
    }

    const { data: members, error: membersError } = await adminSupabase
      .from("membros")
      .select("usuario_id")
      .eq("ativo", true)
      .not("usuario_id", "is", null);
    if (membersError) {
      console.error("Could not load active notification recipients", membersError);
      return jsonResponse(
        { sent: false, error: "Could not load notification recipients" },
        500,
      );
    }
    const recipientIds = [
      ...new Set(
        (members ?? [])
          .map(({ usuario_id }) => usuario_id)
          .filter((userId): userId is string => typeof userId === "string"),
      ),
    ];
    if (recipientIds.length > 0) {
      const { error: recipientsError } = await adminSupabase
        .from("notificacoes_destinatarios")
        .upsert(
          recipientIds.map((userId) => ({
            notificacao_id: inboxNotification.id,
            usuario_id: userId,
          })),
          { onConflict: "notificacao_id,usuario_id", ignoreDuplicates: true },
        );
      if (recipientsError) {
        console.error("Could not save agenda notification recipients", recipientsError);
        return jsonResponse(
          { sent: false, error: "Could not save notification recipients" },
          500,
        );
      }
    }

    const serviceAccountValue = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    const expectedProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    if (!serviceAccountValue || !expectedProjectId) {
      return jsonResponse(
        {
          sent: false,
          notificationId: inboxNotification.id,
          recipientCount: recipientIds.length,
          error: "Firebase push is not configured",
        },
        500,
      );
    }

    const serviceAccount = JSON.parse(serviceAccountValue);
    if (serviceAccount.project_id !== expectedProjectId) {
      console.error("Firebase service account project does not match app");
      return jsonResponse(
        {
          sent: false,
          notificationId: inboxNotification.id,
          recipientCount: recipientIds.length,
          errorCode: "service_account_project_mismatch",
        },
        500,
      );
    }
    if (
      typeof serviceAccount.client_email !== "string" ||
      typeof serviceAccount.private_key !== "string"
    ) {
      console.error("Firebase service account JSON is incomplete");
      return jsonResponse(
        {
          sent: false,
          notificationId: inboxNotification.id,
          recipientCount: recipientIds.length,
          errorCode: "invalid_service_account_json",
        },
        500,
      );
    }

    const firebaseApp = getApps()[0] ?? initializeApp({
      credential: cert(serviceAccount),
      projectId: expectedProjectId,
    });
    const messageId = await getMessaging(firebaseApp).send({
      topic: "agenda",
      notification: {
        title: notification.title,
        body: notificationBody,
      },
      data: {
        eventId: event.id,
        operation: type,
        title: notification.title,
        body: notificationBody,
        notificationId: inboxNotification.id,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "agenda_alteracoes",
        },
      },
      apns: {
        payload: {
          aps: { sound: "default" },
        },
      },
    });

    const { data: webDevices, error: webDevicesError } = await adminSupabase
      .from("device_tokens")
      .select("token")
      .eq("platform", "web")
      .eq("agenda_enabled", true);
    if (webDevicesError) {
      console.error("Could not load web push tokens", webDevicesError);
      return jsonResponse(
        { sent: false, error: "Could not load web push tokens" },
        500,
      );
    }

    const webTokens = [...new Set((webDevices ?? []).map(({ token }) => token))];
    let webSuccessCount = 0;
    let webFailureCount = 0;
    for (let index = 0; index < webTokens.length; index += 500) {
      const result = await getMessaging(firebaseApp).sendEachForMulticast({
        tokens: webTokens.slice(index, index + 500),
        data: {
          eventId: event.id,
          operation: type,
          title: notification.title,
          body: notificationBody,
          notificationId: inboxNotification.id,
        },
        webpush: {
          headers: { Urgency: "high" },
        },
      });
      webSuccessCount += result.successCount;
      webFailureCount += result.failureCount;
    }
    if (webFailureCount > 0) {
      console.error("Some browser push deliveries failed", {
        webFailureCount,
      });
    }

    return jsonResponse({
      sent: true,
      messageId,
      notificationId: inboxNotification.id,
      recipientCount: recipientIds.length,
      webSuccessCount,
      webFailureCount,
    });
  } catch (error) {
    const errorMessage = error instanceof Error
      ? `${error.name}: ${error.message}`
      : String(error);
    const safeDetail = errorMessage
      .replace(
        /-----BEGIN [^-]+-----[\s\S]*?-----END [^-]+-----/g,
        "[redacted private key]",
      )
      .replace(/\bBearer\s+\S+/gi, "******")
      .slice(0, 240);
    console.error("Failed to dispatch agenda push", safeDetail);
    return jsonResponse(
      { sent: false, error: "Notification could not be sent" },
      500,
    );
  }
});
