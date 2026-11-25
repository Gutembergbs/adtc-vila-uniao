create or replace function public.admin_promover_visitante_a_membro(
  p_visitante_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  visitante public.visitantes%rowtype;
  novo_membro_id uuid;
begin
  if auth.uid() is null or not public.eh_administrador() then
    raise exception 'Somente administradores podem promover visitantes.';
  end if;

  select *
    into visitante
  from public.visitantes
  where id = p_visitante_id
  for update;

  if not found then
    raise exception 'O cadastro de visitante não foi encontrado.';
  end if;

  if exists (
    select 1
    from public.membros
    where lower(email) = lower(visitante.email)
  ) then
    raise exception 'Já existe um cadastro de membro com este e-mail.';
  end if;

  insert into public.membros (
    usuario_id,
    email,
    nome,
    telefone,
    departamento,
    ativo,
    status_acesso
  )
  values (
    visitante.usuario_id,
    lower(visitante.email),
    visitante.nome,
    visitante.telefone,
    '',
    false,
    'pendente'
  )
  returning id into novo_membro_id;

  delete from public.visitantes
  where id = p_visitante_id;

  return novo_membro_id;
end;
$$;

revoke all on function public.admin_promover_visitante_a_membro(uuid)
  from public, anon;
grant execute on function public.admin_promover_visitante_a_membro(uuid)
  to authenticated;

create or replace function public.admin_excluir_visitante(
  p_visitante_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  visitante_usuario_id uuid;
begin
  if auth.uid() is null or not public.eh_administrador() then
    raise exception 'Somente administradores podem excluir visitantes.';
  end if;

  select usuario_id
    into visitante_usuario_id
  from public.visitantes
  where id = p_visitante_id
  for update;

  if visitante_usuario_id is null then
    raise exception 'O cadastro de visitante não foi encontrado.';
  end if;

  if exists (
    select 1
    from public.administradores
    where usuario_id = visitante_usuario_id
  ) then
    raise exception 'Uma conta administradora não pode ser excluída como visitante.';
  end if;

  if exists (
    select 1
    from public.membros
    where usuario_id = visitante_usuario_id
  ) then
    raise exception 'A conta também possui cadastro de membro e não pode ser excluída como visitante.';
  end if;

  delete from auth.users
  where id = visitante_usuario_id;

  if not found then
    raise exception 'Não foi possível excluir a conta do visitante.';
  end if;
end;
$$;

revoke all on function public.admin_excluir_visitante(uuid)
  from public, anon;
grant execute on function public.admin_excluir_visitante(uuid)
  to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'visitantes'
  ) then
    alter publication supabase_realtime add table public.visitantes;
  end if;
end;
$$;
