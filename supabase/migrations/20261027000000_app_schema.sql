-- Consolidated current app schema changes.
-- Replaces the unrecorded 20261026-20261032 migration files.

alter table public.eventos_agenda
  add column if not exists data_evento date;

create index if not exists eventos_agenda_data_horario_idx
  on public.eventos_agenda (data_evento, horario);

alter table public.departamentos
  add column if not exists historico_conjunto text;

alter table public.membros
  add column if not exists data_nascimento date;

grant update (data_nascimento)
  on public.membros to authenticated;

alter table public.membros
  add column if not exists apelido text;

grant update (apelido)
  on public.membros to authenticated;

alter table public.departamentos
  add column if not exists ordem integer;

with ordered_departments as (
  select id, row_number() over (order by nome, id) - 1 as ordem
  from public.departamentos
)
update public.departamentos as department
set ordem = ordered_departments.ordem
from ordered_departments
where department.id = ordered_departments.id
  and department.ordem is null;

alter table public.departamentos
  alter column ordem set default 0,
  alter column ordem set not null;

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

create table if not exists public.departamentos_membros (
  id uuid primary key default gen_random_uuid(),
  departamento_id text not null references public.departamentos(id) on delete cascade,
  membro_id uuid not null references public.membros(id) on delete cascade,
  cargo text not null,
  criado_em timestamptz not null default now(),
  unique (departamento_id, membro_id, cargo)
);

alter table public.departamentos_membros enable row level security;
grant select, insert, update, delete
  on public.departamentos_membros to authenticated;

drop policy if exists "Admins gerenciam equipe dos departamentos"
  on public.departamentos_membros;
create policy "Admins gerenciam equipe dos departamentos"
  on public.departamentos_membros for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

alter table public.membros
  add column if not exists foto_path text;

grant update (nome, telefone, congregacao, data_batismo, departamento, foto_path)
  on public.membros to authenticated;

create or replace function public.proteger_dados_membro()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if current_user in ('anon', 'authenticated')
    and not public.eh_administrador()
    and (
      new.id is distinct from old.id
      or new.usuario_id is distinct from old.usuario_id
      or new.matricula is distinct from old.matricula
      or new.email is distinct from old.email
      or new.ativo is distinct from old.ativo
      or new.criado_em is distinct from old.criado_em
    ) then
    raise exception 'Campos restritos do cadastro não podem ser alterados pelo membro.';
  end if;
  return new;
end;
$$;

insert into storage.buckets (id, name, public)
values ('fotos-membros', 'fotos-membros', false)
on conflict (id) do update set public = false;

drop policy if exists "Membros leem sua propria foto"
  on storage.objects;
create policy "Membros leem sua propria foto"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Membros enviam sua propria foto"
  on storage.objects;
create policy "Membros enviam sua propria foto"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Membros atualizam sua propria foto"
  on storage.objects;
create policy "Membros atualizam sua propria foto"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Membros removem sua propria foto"
  on storage.objects;
create policy "Membros removem sua propria foto"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop index if exists public.departamentos_membros_lider_unico_idx;

create table if not exists public.avisos_membros (
  id uuid primary key default gen_random_uuid(),
  membro_id uuid not null references public.membros(id) on delete cascade,
  departamento_id text references public.departamentos(id) on delete set null,
  titulo text not null,
  resumo text not null default '',
  conteudo text not null,
  categoria text not null default 'Pessoal',
  criado_em timestamptz not null default now()
);

create index if not exists avisos_membros_membro_criado_idx
  on public.avisos_membros (membro_id, criado_em desc);

alter table public.avisos_membros enable row level security;
grant select, insert, update, delete on public.avisos_membros to authenticated;

drop policy if exists "Membros leem avisos direcionados a si"
  on public.avisos_membros;
create policy "Membros leem avisos direcionados a si"
  on public.avisos_membros for select
  to authenticated
  using (
    exists (
      select 1
      from public.membros
      where membros.id = avisos_membros.membro_id
        and membros.usuario_id = auth.uid()
        and membros.ativo
    )
  );

drop policy if exists "Admins gerenciam avisos direcionados"
  on public.avisos_membros;
create policy "Admins gerenciam avisos direcionados"
  on public.avisos_membros for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

create table if not exists public.escalas_membros (
  id uuid primary key default gen_random_uuid(),
  membro_id uuid not null references public.membros(id) on delete cascade,
  departamento_id text not null references public.departamentos(id) on delete cascade,
  evento_id text not null references public.eventos_agenda(id) on delete cascade,
  data date not null,
  criado_em timestamptz not null default now(),
  unique (membro_id, departamento_id, evento_id, data)
);

create index if not exists escalas_membros_membro_data_idx
  on public.escalas_membros (membro_id, data);

alter table public.escalas_membros enable row level security;
grant select, insert, update, delete on public.escalas_membros to authenticated;

drop policy if exists "Membros leem suas proprias escalas"
  on public.escalas_membros;
create policy "Membros leem suas proprias escalas"
  on public.escalas_membros for select
  to authenticated
  using (
    exists (
      select 1
      from public.membros
      where membros.id = escalas_membros.membro_id
        and membros.usuario_id = auth.uid()
        and membros.ativo
    )
  );

drop policy if exists "Admins gerenciam escalas individuais"
  on public.escalas_membros;
create policy "Admins gerenciam escalas individuais"
  on public.escalas_membros for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

drop policy if exists "Membros leem seus cargos departamentais"
  on public.departamentos_membros;
create policy "Membros leem seus cargos departamentais"
  on public.departamentos_membros for select
  to authenticated
  using (
    exists (
      select 1
      from public.membros
      where membros.id = departamentos_membros.membro_id
        and membros.usuario_id = auth.uid()
        and membros.ativo
    )
  );

alter table public.avisos_membros
  add column if not exists visualizado_em timestamptz;

grant update (visualizado_em) on public.avisos_membros to authenticated;

drop policy if exists "Membros marcam seus avisos como visualizados"
  on public.avisos_membros;
create policy "Membros marcam seus avisos como visualizados"
  on public.avisos_membros for update
  to authenticated
  using (
    exists (
      select 1
      from public.membros
      where membros.id = avisos_membros.membro_id
        and membros.usuario_id = auth.uid()
        and membros.ativo
    )
  )
  with check (
    exists (
      select 1
      from public.membros
      where membros.id = avisos_membros.membro_id
        and membros.usuario_id = auth.uid()
        and membros.ativo
    )
  );

create or replace function public.proteger_conteudo_aviso_membro()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if not public.eh_administrador() and (
    new.id is distinct from old.id
    or new.membro_id is distinct from old.membro_id
    or new.departamento_id is distinct from old.departamento_id
    or new.titulo is distinct from old.titulo
    or new.resumo is distinct from old.resumo
    or new.conteudo is distinct from old.conteudo
    or new.categoria is distinct from old.categoria
    or new.criado_em is distinct from old.criado_em
    or (old.visualizado_em is not null and new.visualizado_em is distinct from old.visualizado_em)
  ) then
    raise exception 'Membros podem apenas marcar seus avisos como visualizados.';
  end if;
  if not public.eh_administrador() and
    new.visualizado_em is distinct from old.visualizado_em then
    if old.visualizado_em is not null or new.visualizado_em is null then
      raise exception 'O registro de visualização não pode ser alterado.';
    end if;
    new.visualizado_em = now();
  end if;
  return new;
end;
$$;

drop trigger if exists proteger_conteudo_aviso_membro
  on public.avisos_membros;
create trigger proteger_conteudo_aviso_membro
  before update on public.avisos_membros
  for each row execute function public.proteger_conteudo_aviso_membro();

drop policy if exists "Restringe leitura avisos pessoais ao destinatario"
  on public.avisos_membros;
create policy "Restringe leitura avisos pessoais ao destinatario"
  on public.avisos_membros as restrictive
  for select
  to authenticated
  using (
    public.eh_administrador()
    or exists (
      select 1
      from public.membros
      where membros.id = avisos_membros.membro_id
        and membros.usuario_id = auth.uid()
        and membros.ativo
    )
  );

create or replace function public.aniversariantes_do_mes(p_mes integer)
returns table (nome text, dia integer, foto_path text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    membros.nome,
    extract(day from membros.data_nascimento)::integer,
    membros.foto_path
  from public.membros as membros
  where p_mes between 1 and 12
    and membros.ativo
    and membros.data_nascimento is not null
    and extract(month from membros.data_nascimento)::integer = p_mes
  order by extract(day from membros.data_nascimento), membros.nome;
$$;

revoke all on function public.aniversariantes_do_mes(integer) from public;
revoke all on function public.aniversariantes_do_mes(integer) from anon;
grant execute on function public.aniversariantes_do_mes(integer)
  to authenticated;

drop policy if exists "Membros autenticados leem fotos de perfil"
  on storage.objects;
create policy "Membros autenticados leem fotos de perfil"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'fotos-membros');

alter table public.eventos_agenda
  add column if not exists anexo_path text,
  add column if not exists anexo_nome text;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'materiais-eventos',
  'materiais-eventos',
  false,
  20971520,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Membros ativos e admins leem anexos da agenda"
  on storage.objects;
create policy "Membros ativos e admins leem anexos da agenda"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'materiais-eventos'
    and exists (
      select 1
      from public.eventos_agenda as evento
      where evento.anexo_path = storage.objects.name
        and (
          public.eh_administrador()
          or exists (
            select 1
            from public.membros as membro
            where membro.usuario_id = auth.uid()
              and membro.ativo
          )
        )
    )
  );

drop policy if exists "Admins enviam anexos da agenda"
  on storage.objects;
create policy "Admins enviam anexos da agenda"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'materiais-eventos'
    and public.eh_administrador()
  );

drop policy if exists "Admins atualizam anexos da agenda"
  on storage.objects;
create policy "Admins atualizam anexos da agenda"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'materiais-eventos'
    and public.eh_administrador()
  )
  with check (
    bucket_id = 'materiais-eventos'
    and public.eh_administrador()
  );

drop policy if exists "Admins removem anexos da agenda"
  on storage.objects;
create policy "Admins removem anexos da agenda"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'materiais-eventos'
    and public.eh_administrador()
  );
