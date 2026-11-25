-- Tokens de notificacao push associados a usuarios autenticados.
-- Seguro para executar novamente: nao apaga tokens nem outras tabelas.
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android', 'ios', 'web')),
  agenda_enabled boolean not null default false,
  notifications_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens
  add column if not exists notifications_enabled boolean not null default false;

create index if not exists device_tokens_user_id_idx
  on public.device_tokens (user_id);

create unique index if not exists device_tokens_user_id_token_key
  on public.device_tokens (user_id, token);

create or replace function public.set_device_token_timestamp()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_device_token_timestamp on public.device_tokens;
create trigger trg_device_token_timestamp
  before update on public.device_tokens
  for each row execute function public.set_device_token_timestamp();

alter table public.device_tokens enable row level security;

grant select, insert, update, delete on public.device_tokens to authenticated;

drop policy if exists "Usuarios gerenciam seus proprios tokens push"
  on public.device_tokens;
create policy "Usuarios gerenciam seus proprios tokens push"
  on public.device_tokens for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
