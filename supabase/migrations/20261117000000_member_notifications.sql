alter table public.device_tokens
  add column if not exists notifications_enabled boolean not null default false;

update public.device_tokens
set notifications_enabled = agenda_enabled or agenda_reminders_enabled
where not notifications_enabled;

create table if not exists public.notificacoes (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('evento', 'personalizada')),
  titulo text not null,
  resumo text not null default '',
  conteudo text not null,
  categoria text not null default 'Geral',
  evento_id text references public.eventos_agenda(id) on delete set null,
  criado_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now(),
  enviado_em timestamptz
);

create index if not exists notificacoes_tipo_criado_idx
  on public.notificacoes (tipo, criado_em desc);

create table if not exists public.notificacoes_destinatarios (
  id uuid primary key default gen_random_uuid(),
  notificacao_id uuid not null
    references public.notificacoes(id) on delete cascade,
  usuario_id uuid not null references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now(),
  lida_em timestamptz,
  unique (notificacao_id, usuario_id)
);

create index if not exists notificacoes_destinatarios_usuario_idx
  on public.notificacoes_destinatarios (usuario_id, lida_em, criado_em desc);

alter table public.notificacoes enable row level security;
alter table public.notificacoes_destinatarios enable row level security;

grant select, insert, update, delete on public.notificacoes to authenticated;
grant select, insert, delete on public.notificacoes_destinatarios to authenticated;
grant update (lida_em) on public.notificacoes_destinatarios to authenticated;

drop policy if exists "Membros leem notificacoes recebidas"
  on public.notificacoes;
create policy "Membros leem notificacoes recebidas"
  on public.notificacoes for select
  to authenticated
  using (
    public.eh_administrador()
    or exists (
      select 1
      from public.notificacoes_destinatarios destinatario
      where destinatario.notificacao_id = notificacoes.id
        and destinatario.usuario_id = auth.uid()
    )
  );

drop policy if exists "Admins gerenciam notificacoes"
  on public.notificacoes;
create policy "Admins gerenciam notificacoes"
  on public.notificacoes for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

drop policy if exists "Membros leem seus destinatarios"
  on public.notificacoes_destinatarios;
create policy "Membros leem seus destinatarios"
  on public.notificacoes_destinatarios for select
  to authenticated
  using (
    usuario_id = auth.uid()
    or public.eh_administrador()
  );

drop policy if exists "Membros marcam suas notificacoes como lidas"
  on public.notificacoes_destinatarios;
create policy "Membros marcam suas notificacoes como lidas"
  on public.notificacoes_destinatarios for update
  to authenticated
  using (usuario_id = auth.uid())
  with check (usuario_id = auth.uid());

drop policy if exists "Admins gerenciam destinatarios"
  on public.notificacoes_destinatarios;
create policy "Admins gerenciam destinatarios"
  on public.notificacoes_destinatarios for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notificacoes'
  ) then
    alter publication supabase_realtime
      add table public.notificacoes;
  end if;

  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notificacoes_destinatarios'
  ) then
    alter publication supabase_realtime
      add table public.notificacoes_destinatarios;
  end if;
end;
$$;
