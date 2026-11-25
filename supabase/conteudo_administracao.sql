-- Conteúdo público pode ser lido por visitantes; somente admins autenticados alteram.
create table if not exists public.administradores (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now()
);

create table if not exists public.departamentos (
  id text primary key,
  nome text not null,
  ordem integer not null default 0,
  nome_conjunto text,
  descricao text not null,
  responsabilidades text[] not null default '{}',
  responsavel text not null,
  horario_reuniao text not null,
  icone integer not null,
  cor bigint not null,
  tags text[] not null default '{}',
  instagram text,
  historico_conjunto text
);

alter table public.departamentos
  add column if not exists historico_conjunto text;
alter table public.departamentos
  add column if not exists ordem integer not null default 0;

create table if not exists public.eventos_agenda (
  id text primary key,
  titulo text not null,
  subtitulo text not null,
  horario text not null,
  data_evento date,
  descricao_dias text not null,
  dia_semana smallint check (dia_semana between 1 and 7),
  local text not null,
  tipo text not null check (
    tipo in ('culto', 'oracao', 'ensaio', 'estudo', 'consagracao', 'missao', 'especial')
  ),
  departamento_id text references public.departamentos(id) on delete set null,
  ciclo_recorrencia text,
  icone integer not null,
  cor bigint not null,
  observacoes text not null,
  tema_mensal boolean not null default false,
  anexo_path text,
  anexo_nome text,
  link_texto text,
  link_url text
);

-- Compatibilidade com projetos que ja tinham colunas antigas na tabela.
alter table public.eventos_agenda
  add column if not exists data_evento date,
  add column if not exists link_texto text,
  add column if not exists link_url text;

alter table public.administradores enable row level security;
alter table public.departamentos enable row level security;
alter table public.eventos_agenda enable row level security;

-- A função evita políticas recursivas ao consultar a tabela de administradores.
create or replace function public.eh_administrador()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.administradores
    where usuario_id = auth.uid()
  );
$$;

revoke all on function public.eh_administrador() from public, anon;
grant execute on function public.eh_administrador() to authenticated;

grant select on public.departamentos, public.eventos_agenda to anon, authenticated;
grant insert, update, delete on public.departamentos, public.eventos_agenda to authenticated;
grant select on public.administradores to authenticated;

drop policy if exists "Admin pode consultar o proprio cadastro"
  on public.administradores;
create policy "Admin pode consultar o proprio cadastro"
  on public.administradores for select
  to authenticated
  using (usuario_id = auth.uid());

drop policy if exists "Leitura publica de departamentos"
  on public.departamentos;
create policy "Leitura publica de departamentos"
  on public.departamentos for select
  to anon, authenticated
  using (true);

drop policy if exists "Admins gerenciam departamentos"
  on public.departamentos;
create policy "Admins gerenciam departamentos"
  on public.departamentos for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

create or replace function public.definir_ordem_departamentos(
  p_department_ids text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  department_count integer;
begin
  if not public.eh_administrador() then
    raise exception 'Somente administradores podem ordenar departamentos.';
  end if;

  lock table public.departamentos in share row exclusive mode;
  select count(*) into department_count from public.departamentos;

  if coalesce(cardinality(p_department_ids), 0) <> department_count
    or (
      select count(distinct department_id)
      from unnest(p_department_ids) as values_list(department_id)
    ) <> department_count
    or exists (
      select 1
      from unnest(p_department_ids) as requested(department_id)
      where not exists (
        select 1
        from public.departamentos as department
        where department.id = requested.department_id
      )
    ) then
    raise exception 'A lista de departamentos está desatualizada.';
  end if;

  update public.departamentos as department
  set ordem = requested.position - 1
  from unnest(p_department_ids) with ordinality
    as requested(department_id, position)
  where department.id = requested.department_id;
end;
$$;

revoke all on function public.definir_ordem_departamentos(text[])
  from public, anon;
grant execute on function public.definir_ordem_departamentos(text[])
  to authenticated;

drop policy if exists "Leitura publica da agenda"
  on public.eventos_agenda;
create policy "Leitura publica da agenda"
  on public.eventos_agenda for select
  to anon, authenticated
  using (true);

drop policy if exists "Admins gerenciam agenda"
  on public.eventos_agenda;
create policy "Admins gerenciam agenda"
  on public.eventos_agenda for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

create index if not exists eventos_agenda_dia_horario_idx
  on public.eventos_agenda (dia_semana, horario);
create index if not exists eventos_agenda_data_horario_idx
  on public.eventos_agenda (data_evento, horario);

-- Habilita avisos em tempo real quando eventos são inseridos, alterados ou removidos.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'eventos_agenda'
  ) then
    alter publication supabase_realtime add table public.eventos_agenda;
  end if;
end;
$$;

-- Para habilitar o primeiro admin, crie o usuário em Authentication > Users e rode:
-- insert into public.administradores (usuario_id)
-- select id from auth.users where email = 'admin@exemplo.com'
-- on conflict do nothing;