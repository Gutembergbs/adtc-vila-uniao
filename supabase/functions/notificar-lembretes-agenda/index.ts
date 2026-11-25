import { cert, getApps, initializeApp } from "npm:firebase-admin@13.4.0/app";
import { getMessaging } from "npm:firebase-admin@13.4.0/messaging";
import { createClient } from "npm:@supabase/supabase-js@2";

const timeZone = "America/Fortaleza";
const allowedReminderMinutes = new Set([10, 15, 30, 60]);
const eventReminderTitles: Record<string, string> = {
  culto: "Culto próximo",
  oracao: "Oração próxima",
  ensaio: "Ensaio próximo",
  estudo: "Estudo próximo",
  consagracao: "Consagração próxima",
  missao: "Missão próxima",
  especial: "Evento próximo",
};
const weekdayNames = [
  "segunda",
  "terca",
  "quarta",
  "quinta",
  "sexta",
  "sabado",
  "domingo",
];

type AgendaEvent = {
  id: string;
  titulo: string;
  horario: string;
  data_evento: string | null;
  dia_semana: number | null;
  descricao_dias: string;
  ciclo_recorrencia: string | null;
  tema_mensal: boolean;
  local: string;
  tipo: string;
};

function jsonResponse(body: unknown, status = 200) {
  return Response.json(body, { status });
}

function localDateParts(date: Date) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const values = Object.fromEntries(
    parts.map(({ type, value }) => [type, value]),
  );
  return {
    date: `${values.year}-${values.month}-${values.day}`,
    hour: Number(values.hour),
    minute: Number(values.minute),
  };
}

function localTimeZoneOffset(date: Date) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const values = Object.fromEntries(
    parts.map(({ type, value }) => [type, Number(value)]),
  );
  const localAsUtc = Date.UTC(
    values.year,
    values.month - 1,
    values.day,
    values.hour,
    values.minute,
    values.second,
  );
  return localAsUtc - date.getTime();
}

function localOccurrenceUtc(date: string, hour: number, minute: number) {
  const [year, month, day] = date.split("-").map(Number);
  const localAsUtc = Date.UTC(year, month - 1, day, hour, minute);
  let timestamp = localAsUtc;
  for (let attempt = 0; attempt < 2; attempt++) {
    timestamp = localAsUtc - localTimeZoneOffset(new Date(timestamp));
  }
  return new Date(timestamp).toISOString();
}

function normalizeText(value: string) {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase();
}

function isoWeekday(date: string) {
  const weekday = new Date(`${date}T12:00:00Z`).getUTCDay();
  return weekday === 0 ? 7 : weekday;
}

function occursOnDate(event: AgendaEvent, date: string) {
  if (event.data_evento) return event.data_evento === date;

  const weekday = isoWeekday(date);
  if (event.tema_mensal) {
    const ordinal = Number.parseInt(
      (event.ciclo_recorrencia ?? event.descricao_dias).match(/\d+/)?.[0] ?? "",
      10,
    );
    const dayOfMonth = Number(date.slice(-2));
    return weekday === 7 && Number.isInteger(ordinal) &&
      Math.floor((dayOfMonth - 1) / 7) + 1 === ordinal;
  }
  if (event.dia_semana != null) return event.dia_semana === weekday;

  const description = normalizeText(event.descricao_dias);
  const cycle = normalizeText(event.ciclo_recorrencia ?? "");
  if (
    cycle.includes("diario") ||
    description.includes("todos os dias") ||
    description.includes("segunda a domingo")
  ) {
    return true;
  }

  const foundDays = weekdayNames
    .map((name, index) =>
      new RegExp(`\\b${name}`).test(description) ? index + 1 : null
    )
    .filter((day): day is number => day !== null);
  if (foundDays.length === 0) return false;

  const range = description.match(
    /\b(segunda|terca|quarta|quinta|sexta|sabado|domingo)\s+a\s+(segunda|terca|quarta|quinta|sexta|sabado|domingo)\b/,
  );
  if (!range) return foundDays.includes(weekday);
  const start = weekdayNames.indexOf(range[1]) + 1;
  const end = weekdayNames.indexOf(range[2]) + 1;
  return start <= end
    ? weekday >= start && weekday <= end
    : weekday >= start || weekday <= end;
}

function parseEventTime(value: string) {
  const match = value.match(/^\s*(\d{1,2}):(\d{2})/);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return null;
  return { hour, minute };
}

function reminderTitle(event: AgendaEvent) {
  return `${eventReminderTitles[event.tipo] ?? "Evento próximo"}: ${event.titulo}`;
}

function sameSecret(provided: string | null, expected: string) {
  if (!provided || provided.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < expected.length; index++) {
    difference |= provided.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const reminderSecret = Deno.env.get("AGENDA_REMINDER_SECRET");
  if (!reminderSecret) {
    console.error("Agenda reminder secret is not configured");
    return jsonResponse({ error: "Reminder service is not configured" }, 500);
  }
  if (
    !sameSecret(
      request.headers.get("x-agenda-reminder-secret"),
      reminderSecret,
    )
  ) {
    return jsonResponse({ error: "Authentication required" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const serviceAccountValue = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  const expectedProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (
    !supabaseUrl ||
    !serviceRoleKey ||
    !serviceAccountValue ||
    !expectedProjectId
  ) {
    console.error("Agenda reminder server configuration is incomplete");
    return jsonResponse({ error: "Reminder service is not configured" }, 500);
  }

  try {
    const adminSupabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const [{ data: events, error: eventsError }, { data: devices, error: devicesError }] =
      await Promise.all([
        adminSupabase
          .from("eventos_agenda")
          .select(
            "id,titulo,horario,data_evento,dia_semana,descricao_dias,ciclo_recorrencia,tema_mensal,local,tipo",
          ),
        adminSupabase
          .from("device_tokens")
          .select("token,agenda_reminder_minutes")
          .eq("platform", "web")
          .eq("agenda_reminders_enabled", true),
      ]);
    if (eventsError) {
      console.error("Could not load agenda events", eventsError);
      return jsonResponse({ error: "Could not load agenda events" }, 500);
    }
    if (devicesError) {
      console.error("Could not load subscribed browsers", devicesError);
      return jsonResponse({ error: "Could not load subscribed browsers" }, 500);
    }
    if (!devices?.length || !events?.length) {
      return jsonResponse({ sent: 0 });
    }

    const serviceAccount = JSON.parse(serviceAccountValue);
    if (
      serviceAccount.project_id !== expectedProjectId ||
      typeof serviceAccount.client_email !== "string" ||
      typeof serviceAccount.private_key !== "string"
    ) {
      console.error("Firebase service account configuration is invalid");
      return jsonResponse({ error: "Reminder service is not configured" }, 500);
    }
    const firebaseApp = getApps()[0] ?? initializeApp({
      credential: cert(serviceAccount),
      projectId: expectedProjectId,
    });
    const messaging = getMessaging(firebaseApp);
    const devicesByLeadTime = new Map<number, Set<string>>();
    for (const device of devices) {
      const minutes = Number(device.agenda_reminder_minutes);
      if (!allowedReminderMinutes.has(minutes)) continue;
      const tokens = devicesByLeadTime.get(minutes) ?? new Set<string>();
      tokens.add(device.token);
      devicesByLeadTime.set(minutes, tokens);
    }

    const now = new Date();
    let sent = 0;
    let failed = 0;
    for (const [minutesBefore, tokenSet] of devicesByLeadTime) {
      const target = localDateParts(
        new Date(now.getTime() + minutesBefore * 60_000),
      );
      const dueEvents = (events as AgendaEvent[]).filter((event) => {
        const time = parseEventTime(event.horario);
        return time != null &&
          time.hour === target.hour &&
          time.minute === target.minute &&
          occursOnDate(event, target.date);
      });

      for (const event of dueEvents) {
        const occurrenceAt = localOccurrenceUtc(
          target.date,
          target.hour,
          target.minute,
        );
        const { data: claim, error: claimError } = await adminSupabase
          .from("agenda_reminder_deliveries")
          .insert({
            event_id: event.id,
            occurrence_at: occurrenceAt,
            minutes_before: minutesBefore,
          })
          .select("event_id")
          .maybeSingle();
        if (claimError?.code === "23505") continue;
        if (claimError) {
          console.error("Could not claim agenda reminder", claimError);
          failed++;
          continue;
        }
        if (!claim) continue;

        const tokens = [...tokenSet];
        try {
          for (let index = 0; index < tokens.length; index += 500) {
            const result = await messaging.sendEachForMulticast({
              tokens: tokens.slice(index, index + 500),
              data: {
                eventId: event.id,
                operation: "reminder",
                title: reminderTitle(event),
                body: `Começa em ${minutesBefore} min • ${event.local}`,
              },
              webpush: {
                headers: { Urgency: "high" },
              },
            });
            sent += result.successCount;
            failed += result.failureCount;
            if (result.failureCount > 0) {
              console.error("Some agenda reminder deliveries failed", {
                eventId: event.id,
                failureCount: result.failureCount,
              });
            }
          }
        } catch (error) {
          const { error: releaseError } = await adminSupabase
            .from("agenda_reminder_deliveries")
            .delete()
            .eq("event_id", event.id)
            .eq("occurrence_at", occurrenceAt)
            .eq("minutes_before", minutesBefore);
          if (releaseError) {
            console.error("Could not release failed reminder claim", {
              eventId: event.id,
              releaseError,
            });
          }
          console.error("Could not send agenda reminder", error);
          failed++;
        }
      }
    }

    return jsonResponse({ sent, failed });
  } catch (error) {
    console.error("Failed to process agenda reminders", error);
    return jsonResponse({ error: "Could not process agenda reminders" }, 500);
  }
});
