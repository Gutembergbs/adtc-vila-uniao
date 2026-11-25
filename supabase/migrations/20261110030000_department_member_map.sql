drop function if exists public.listar_membros_departamento(
  text,
  text,
  text
);

create function public.listar_membros_departamento(
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
  where auth.uid() is not null
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
