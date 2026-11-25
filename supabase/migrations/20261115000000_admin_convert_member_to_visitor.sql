create or replace function public.admin_converter_membro_em_visitante(
  p_membro_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  membro public.membros%rowtype;
  novo_visitante_id uuid;
begin
  if auth.uid() is null or not public.eh_administrador() then
    raise exception 'Somente administradores podem converter membros em visitantes.';
  end if;

  select *
    into membro
  from public.membros
  where id = p_membro_id
  for update;

  if not found then
    raise exception 'O cadastro de membro não foi encontrado.';
  end if;

  if membro.usuario_id is null or membro.email is null then
    raise exception 'Somente membros vinculados a uma conta podem ser convertidos.';
  end if;

  if exists (
    select 1
    from public.administradores
    where usuario_id = membro.usuario_id
  ) then
    raise exception 'Uma conta administradora não pode ser convertida em visitante.';
  end if;

  insert into public.visitantes (
    usuario_id,
    email,
    nome,
    telefone
  )
  values (
    membro.usuario_id,
    lower(membro.email),
    membro.nome,
    membro.telefone
  )
  returning id into novo_visitante_id;

  delete from public.membros
  where id = p_membro_id;

  return novo_visitante_id;
end;
$$;

revoke all on function public.admin_converter_membro_em_visitante(uuid)
  from public, anon;
grant execute on function public.admin_converter_membro_em_visitante(uuid)
  to authenticated;
