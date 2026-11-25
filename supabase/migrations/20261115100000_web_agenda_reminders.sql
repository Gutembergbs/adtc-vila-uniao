alter table public.device_tokens
  add column if not exists agenda_reminders_enabled boolean not null default false,
  add column if not exists agenda_reminder_minutes smallint not null default 30;

alter table public.device_tokens
  drop constraint if exists device_tokens_agenda_reminder_minutes_check;

alter table public.device_tokens
  add constraint device_tokens_agenda_reminder_minutes_check
  check (agenda_reminder_minutes in (10, 15, 30, 60));

create table if not exists public.agenda_reminder_deliveries (
  event_id text not null references public.eventos_agenda(id) on delete cascade,
  occurrence_at timestamptz not null,
  minutes_before smallint not null
    check (minutes_before in (10, 15, 30, 60)),
  created_at timestamptz not null default now(),
  primary key (event_id, occurrence_at, minutes_before)
);

alter table public.agenda_reminder_deliveries enable row level security;
revoke all on public.agenda_reminder_deliveries from public, anon, authenticated;
grant select, insert, delete
  on public.agenda_reminder_deliveries to service_role;
