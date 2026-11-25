alter table public.device_tokens
  drop constraint if exists device_tokens_platform_check;

alter table public.device_tokens
  add constraint device_tokens_platform_check
  check (platform in ('android', 'ios', 'web'));

alter table public.device_tokens
  add column if not exists agenda_enabled boolean not null default false;
