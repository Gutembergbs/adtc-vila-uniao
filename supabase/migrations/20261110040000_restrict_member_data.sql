create or replace function public.vincular_usuario_membro()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  pre_cadastrado_id uuid;
begin
  if new.email is null then
    raise exception 'Cadastro não autorizado. Confirme seus dados com a secretaria.';
  end if;

  select membro.id
    into pre_cadastrado_id
  from public.membros as membro
  where lower(membro.email) = lower(new.email)
    and membro.usuario_id is null
    and membro.ativo
  order by membro.id
  limit 1
  for update;

  if pre_cadastrado_id is null then
    raise exception 'Cadastro não autorizado. Confirme seus dados com a secretaria.';
  end if;

  update public.membros as membro
  set usuario_id = new.id,
      nome = case
        when membro.nome = membro.email then
          coalesce(
            nullif(new.raw_user_meta_data ->> 'nome', ''),
            split_part(new.email, '@', 1)
          )
        else membro.nome
      end,
      telefone = coalesce(
        nullif(membro.telefone, ''),
        coalesce(new.raw_user_meta_data ->> 'telefone', '')
      )
  where membro.id = pre_cadastrado_id;

  return new;
end;
$$;

create or replace function public.aniversariantes_do_mes(p_mes integer)
returns table (nome text, dia integer, foto_path text)
language sql
stable
security definer
set search_path = ''
as $$
  select
    membro.nome,
    extract(day from membro.data_nascimento)::integer,
    membro.foto_path
  from public.membros as membro
  where public.eh_administrador()
    and p_mes between 1 and 12
    and membro.ativo
    and membro.data_nascimento is not null
    and extract(month from membro.data_nascimento)::integer = p_mes
  order by extract(day from membro.data_nascimento), membro.nome;
$$;

revoke all on function public.aniversariantes_do_mes(integer)
  from public, anon, authenticated;
grant execute on function public.aniversariantes_do_mes(integer)
  to authenticated;

create or replace function public.listar_membros_departamento(
  p_departamento_id text,
  p_departamento_nome text,
  p_departamento_exibicao text
)
returns table (
  membro_id uuid,
  nome_exibicao text,
  funcoes text,
  foto_path text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    membro.id,
    coalesce(
      nullif(pg_catalog.btrim(membro.apelido), ''),
      pg_catalog.btrim(membro.nome)
    ),
    coalesce((
      select pg_catalog.string_agg(funcoes.cargo, ', ' order by funcoes.cargo)
      from (
        select distinct pg_catalog.btrim(vinculo.cargo) as cargo
        from public.departamentos_membros as vinculo
        where vinculo.membro_id = membro.id
          and vinculo.departamento_id = p_departamento_id
          and pg_catalog.btrim(vinculo.cargo) <> ''
      ) as funcoes
    ), ''),
    membro.foto_path
  from public.membros as membro
  where public.eh_administrador()
    and membro.ativo
    and (
      exists (
        select 1
        from pg_catalog.regexp_split_to_table(
          coalesce(membro.departamento, ''),
          '[,;|]'
        ) as departamento_membro(valor)
        where pg_catalog.lower(pg_catalog.btrim(departamento_membro.valor))
          in (
            pg_catalog.lower(pg_catalog.btrim(p_departamento_nome)),
            pg_catalog.lower(pg_catalog.btrim(p_departamento_exibicao))
          )
      )
      or exists (
        select 1
        from public.departamentos_membros as vinculo
        where vinculo.membro_id = membro.id
          and vinculo.departamento_id = p_departamento_id
      )
    )
  order by 2;
$$;

revoke all on function public.listar_membros_departamento(text, text, text)
  from public, anon, authenticated;
grant execute on function public.listar_membros_departamento(text, text, text)
  to authenticated;

create or replace function public.listar_membros_departamento(
  nome_departamento text
)
returns table (nome_exibicao text)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    nullif(pg_catalog.btrim(membro.apelido), ''),
    pg_catalog.btrim(membro.nome)
  )
  from public.membros as membro
  where public.eh_administrador()
    and membro.ativo
    and pg_catalog.btrim(coalesce(nome_departamento, '')) <> ''
    and exists (
      select 1
      from pg_catalog.regexp_split_to_table(
        coalesce(membro.departamento, ''),
        '[,;|]'
      ) as departamento_membro(valor)
      where pg_catalog.lower(pg_catalog.btrim(departamento_membro.valor))
        = pg_catalog.lower(pg_catalog.btrim(nome_departamento))
    )
  order by 1;
$$;

revoke all on function public.listar_membros_departamento(text)
  from public, anon, authenticated;
grant execute on function public.listar_membros_departamento(text)
  to authenticated;

drop policy if exists "Membro consulta proprio cadastro ou admin consulta todos"
  on public.membros;
create policy "Membro ativo consulta proprio cadastro ou admin consulta todos"
  on public.membros for select
  to authenticated
  using (
    public.eh_administrador()
    or (usuario_id = auth.uid() and ativo)
  );

revoke select on public.pedidos_oracao from anon;
grant select on public.pedidos_oracao to authenticated;

drop policy if exists "Leitura publica dos pedidos de oracao"
  on public.pedidos_oracao;
drop policy if exists "Usuarios autenticados leem pedidos de oracao"
  on public.pedidos_oracao;
create policy "Usuarios autenticados leem pedidos de oracao"
  on public.pedidos_oracao for select
  to authenticated
  using (not oculto);

drop policy if exists "Membros autenticados leem fotos de perfil"
  on storage.objects;
drop policy if exists "Admins leem fotos de membros"
  on storage.objects;
create policy "Admins leem fotos de membros"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and public.eh_administrador()
  );