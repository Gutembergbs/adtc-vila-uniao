create table if not exists public.pedidos_oracao_autores (
  pedido_id uuid primary key
    references public.pedidos_oracao(id) on delete cascade,
  usuario_id uuid not null
    references auth.users(id) on delete cascade
);

create index if not exists pedidos_oracao_autores_usuario_idx
  on public.pedidos_oracao_autores (usuario_id);

alter table public.pedidos_oracao_autores enable row level security;
revoke all on public.pedidos_oracao_autores
  from public, anon, authenticated;

create or replace function public.registrar_autor_pedido_oracao()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null then
    insert into public.pedidos_oracao_autores (pedido_id, usuario_id)
    values (new.id, (select auth.uid()));
  end if;
  return new;
end;
$$;

revoke all on function public.registrar_autor_pedido_oracao()
  from public, anon, authenticated;

drop trigger if exists registrar_autor_pedido_oracao
  on public.pedidos_oracao;
create trigger registrar_autor_pedido_oracao
  after insert on public.pedidos_oracao
  for each row execute function public.registrar_autor_pedido_oracao();

create table if not exists public.intercessoes_pedidos (
  pedido_id uuid not null
    references public.pedidos_oracao(id) on delete cascade,
  usuario_id uuid not null
    references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now(),
  primary key (pedido_id, usuario_id)
);

create index if not exists intercessoes_pedidos_usuario_idx
  on public.intercessoes_pedidos (usuario_id, pedido_id);

alter table public.intercessoes_pedidos enable row level security;

revoke all on public.intercessoes_pedidos
  from public, anon, authenticated;
grant select, insert, delete on public.intercessoes_pedidos to authenticated;

drop policy if exists "Usuarios leem suas intercessoes"
  on public.intercessoes_pedidos;
create policy "Usuarios leem suas intercessoes"
  on public.intercessoes_pedidos for select
  to authenticated
  using (usuario_id = (select auth.uid()));

drop policy if exists "Usuarios registram suas intercessoes"
  on public.intercessoes_pedidos;
create policy "Usuarios registram suas intercessoes"
  on public.intercessoes_pedidos for insert
  to authenticated
  with check (
    usuario_id = (select auth.uid())
    and exists (
      select 1
      from public.pedidos_oracao
      where pedidos_oracao.id = intercessoes_pedidos.pedido_id
        and not pedidos_oracao.oculto
    )
  );

drop policy if exists "Usuarios removem suas intercessoes"
  on public.intercessoes_pedidos;
create policy "Usuarios removem suas intercessoes"
  on public.intercessoes_pedidos for delete
  to authenticated
  using (usuario_id = (select auth.uid()));

create or replace function public.atualizar_contagem_intercessoes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.pedidos_oracao
    set quantidade_oracoes = quantidade_oracoes + 1
    where id = new.pedido_id;
    return new;
  end if;

  update public.pedidos_oracao
  set quantidade_oracoes = greatest(0, quantidade_oracoes - 1)
  where id = old.pedido_id;
  return old;
end;
$$;

revoke all on function public.atualizar_contagem_intercessoes()
  from public, anon, authenticated;

drop trigger if exists atualizar_contagem_intercessoes
  on public.intercessoes_pedidos;
create trigger atualizar_contagem_intercessoes
  after insert or delete on public.intercessoes_pedidos
  for each row execute function public.atualizar_contagem_intercessoes();

create or replace function public.listar_lideres_departamento(
  p_departamento_id text
)
returns table (nome_exibicao text, email_contato text)
language sql
stable
security definer
set search_path = ''
as $$
  with viewer as (
    select
      (select auth.uid()) is not null
      and (
        public.eh_administrador()
        or exists (
          select 1
          from public.membros as viewer_member
          where viewer_member.usuario_id = (select auth.uid())
            and viewer_member.ativo
            and viewer_member.status_acesso = 'autorizado'
        )
      ) as pode_ver_email
  ),
  assigned_leaders as (
    select distinct
      coalesce(
        nullif(pg_catalog.btrim(member.apelido), ''),
        pg_catalog.btrim(member.nome)
      ) as nome,
      case
        when viewer.pode_ver_email then nullif(pg_catalog.btrim(member.email), '')
        else null
      end as email
    from public.departamentos_membros as assignment
    join public.membros as member
      on member.id = assignment.membro_id
    cross join viewer
    where assignment.departamento_id = p_departamento_id
      and pg_catalog.lower(pg_catalog.btrim(assignment.cargo)) = 'líder'
      and member.ativo
      and member.status_acesso = 'autorizado'
  )
  select assigned_leaders.nome, assigned_leaders.email
  from assigned_leaders

  union all

  select
    pg_catalog.btrim(department.responsavel),
    null::text
  from public.departamentos as department
  where department.id = p_departamento_id
    and pg_catalog.btrim(coalesce(department.responsavel, '')) <> ''
    and not exists (select 1 from assigned_leaders)
  order by 1;
$$;

revoke all on function public.listar_lideres_departamento(text)
  from public, anon, authenticated;
grant execute on function public.listar_lideres_departamento(text)
  to authenticated;
