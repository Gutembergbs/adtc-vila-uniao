create or replace function public.listar_membros_departamento(
  nome_departamento text
)
returns table (nome_exibicao text)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(btrim(membro.apelido), ''), btrim(membro.nome))
  from public.membros as membro
  where membro.ativo
    and btrim(coalesce(nome_departamento, '')) <> ''
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
  to anon, authenticated;
