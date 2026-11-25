create table if not exists public.visitantes (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null unique references auth.users(id) on delete cascade,
  email text not null unique,
  nome text not null,
  telefone text not null default '',
  bairro text,
  criado_em timestamptz not null default now()
);

alter table public.visitantes enable row level security;
grant select on public.visitantes to authenticated;

drop policy if exists "Visitante consulta proprio cadastro ou admin consulta todos"
  on public.visitantes;
create policy "Visitante consulta proprio cadastro ou admin consulta todos"
  on public.visitantes for select
  to authenticated
  using (public.eh_administrador() or usuario_id = auth.uid());

create or replace function public.vincular_usuario_membro()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  membro_id_encontrado uuid;
  usuario_id_vinculado uuid;
begin
  if new.email is null then
    raise exception 'Informe um e-mail para solicitar acesso ao portal.';
  end if;

  if new.raw_user_meta_data ->> 'tipo_cadastro' = 'visitante' then
    insert into public.visitantes (
      usuario_id, email, nome, telefone
    )
    values (
      new.id,
      lower(new.email),
      coalesce(
        nullif(new.raw_user_meta_data ->> 'nome', ''),
        split_part(new.email, '@', 1)
      ),
      coalesce(new.raw_user_meta_data ->> 'telefone', '')
    );
    return new;
  end if;

  select membro.id, membro.usuario_id
    into membro_id_encontrado, usuario_id_vinculado
  from public.membros as membro
  where lower(membro.email) = lower(new.email)
  order by membro.id
  limit 1
  for update;

  if membro_id_encontrado is not null then
    if usuario_id_vinculado is not null then
      raise exception 'Este e-mail já está vinculado a outra conta.';
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
        ),
        status_acesso = case
          when membro.ativo then 'autorizado'
          else 'pendente'
        end
    where membro.id = membro_id_encontrado;
  else
    insert into public.membros (
      usuario_id, email, nome, telefone, ativo, status_acesso
    )
    values (
      new.id,
      lower(new.email),
      coalesce(
        nullif(new.raw_user_meta_data ->> 'nome', ''),
        split_part(new.email, '@', 1)
      ),
      coalesce(new.raw_user_meta_data ->> 'telefone', ''),
      false,
      'pendente'
    );
  end if;

  return new;
end;
$$;

drop policy if exists "Membro ativo consulta proprio cadastro ou admin consulta todos"
  on public.membros;
drop policy if exists "Membro consulta proprio cadastro ou admin consulta todos"
  on public.membros;
create policy "Membro consulta proprio cadastro ou admin consulta todos"
  on public.membros for select
  to authenticated
  using (public.eh_administrador() or usuario_id = auth.uid());
