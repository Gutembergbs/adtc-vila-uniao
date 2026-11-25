-- Cria a tabela usada pelo mural de pedidos de oração.
create table if not exists public.pedidos_oracao (
  id uuid primary key default gen_random_uuid(),
  nome_autor text not null,
  pedido text not null check (char_length(trim(pedido)) between 1 and 2000),
  categoria text not null check (
    categoria in ('Família', 'Saúde', 'Emprego', 'Espiritual', 'Gratidão', 'Outros')
  ),
  criado_em timestamptz not null default now(),
  quantidade_oracoes integer not null default 0 check (quantidade_oracoes >= 0),
  anonimo boolean not null default false,
  oculto boolean not null default false
);

alter table public.pedidos_oracao
  add column if not exists oculto boolean not null default false;

alter table public.pedidos_oracao enable row level security;

create or replace function public.validar_conteudo_pedido_oracao()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  texto_normalizado text;
begin
  if tg_op = 'UPDATE' then
    if new.nome_autor is not distinct from old.nome_autor
      and new.pedido is not distinct from old.pedido then
      return new;
    end if;
  end if;

  texto_normalizado := lower(translate(
    coalesce(new.pedido, '') || ' ' || coalesce(new.nome_autor, ''),
    'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ',
    'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'
  ));
  texto_normalizado := translate(texto_normalizado, '013457', 'oieast');
  texto_normalizado := btrim(regexp_replace(texto_normalizado, '[^a-z0-9]+', ' ', 'g'));

  if exists (
    select 1
    from unnest(array[
      'arrombado', 'bosta', 'buceta', 'cacete', 'caralho', 'cu',
      'fdp', 'foda', 'fodase', 'merda', 'porra', 'puta', 'puto', 'viado'
    ]) as termo(palavra)
    where termo.palavra = any(string_to_array(texto_normalizado, ' '))
  ) then
    raise exception using
      errcode = '23514',
      message = 'O texto contém linguagem inadequada. Revise o pedido antes de publicar.';
  end if;

  return new;
end;
$$;

drop trigger if exists validar_conteudo_pedido_oracao
  on public.pedidos_oracao;
create trigger validar_conteudo_pedido_oracao
  before insert or update
  on public.pedidos_oracao
  for each row execute function public.validar_conteudo_pedido_oracao();

revoke all on function public.validar_conteudo_pedido_oracao() from public;

grant select, insert on public.pedidos_oracao to anon, authenticated;
grant update (oculto) on public.pedidos_oracao to authenticated;
grant delete on public.pedidos_oracao to authenticated;

drop policy if exists "Leitura publica dos pedidos de oracao"
  on public.pedidos_oracao;
create policy "Leitura publica dos pedidos de oracao"
  on public.pedidos_oracao for select
  to anon, authenticated
  using (not oculto);

drop policy if exists "Admins consultam todos os pedidos de oracao"
  on public.pedidos_oracao;
create policy "Admins consultam todos os pedidos de oracao"
  on public.pedidos_oracao for select
  to authenticated
  using (public.eh_administrador());

drop policy if exists "Publicacao publica de pedidos de oracao"
  on public.pedidos_oracao;
create policy "Publicacao publica de pedidos de oracao"
  on public.pedidos_oracao for insert
  to anon, authenticated
  with check (
    char_length(trim(nome_autor)) between 1 and 120
    and char_length(trim(pedido)) between 1 and 2000
    and not oculto
  );

drop policy if exists "Admins gerenciam pedidos de oracao"
  on public.pedidos_oracao;
create policy "Admins gerenciam pedidos de oracao"
  on public.pedidos_oracao for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

-- Mantém a listagem rápida quando houver muitos pedidos.
create index if not exists pedidos_oracao_criado_em_idx
  on public.pedidos_oracao (criado_em desc);