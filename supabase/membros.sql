-- Cadastros de membros; execute depois de conteudo_administracao.sql.
create table if not exists public.membros (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid unique references auth.users(id) on delete set null,
  matricula bigint generated always as identity unique,
  email text unique,
  nome text not null,
  apelido text,
  telefone text not null default '',
  departamento text not null default '',
  foto_path text,
  congregacao text not null default 'ADTC Vila União - Sobral',
  data_nascimento date,
  data_batismo text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

alter table public.membros
  alter column email drop not null;

create table if not exists public.departamentos_membros (
  id uuid primary key default gen_random_uuid(),
  departamento_id text not null references public.departamentos(id) on delete cascade,
  membro_id uuid not null references public.membros(id) on delete cascade,
  cargo text not null,
  criado_em timestamptz not null default now(),
  unique (departamento_id, membro_id, cargo)
);

alter table public.membros
  add column if not exists foto_path text;
alter table public.membros
  add column if not exists data_nascimento date;
alter table public.membros
  add column if not exists apelido text;

alter table public.membros enable row level security;
alter table public.departamentos_membros enable row level security;

-- Ao confirmar um cadastro Auth, vincula o usuário ao pré-cadastro pelo e-mail.
create or replace function public.vincular_usuario_membro()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is null then
    return new;
  end if;

  insert into public.membros (usuario_id, email, nome, telefone)
  values (
    new.id,
    lower(new.email),
    coalesce(nullif(new.raw_user_meta_data ->> 'nome', ''), split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'telefone', '')
  )
  on conflict (email) do update
    set usuario_id = excluded.usuario_id,
        nome = case
          when public.membros.nome = public.membros.email then excluded.nome
          else public.membros.nome
        end,
        telefone = coalesce(nullif(public.membros.telefone, ''), excluded.telefone)
    where public.membros.usuario_id is null;

  if not found then
    raise exception 'Este e-mail já está vinculado a outra conta.';
  end if;

  return new;
end;
$$;

drop trigger if exists ao_criar_usuario_vincular_membro on auth.users;
create trigger ao_criar_usuario_vincular_membro
  after insert on auth.users
  for each row execute function public.vincular_usuario_membro();

-- Membros leem apenas o próprio perfil; admins podem gerenciar todos os cadastros.
grant select on public.membros to authenticated;
grant insert, update, delete on public.membros to authenticated;
grant update (
  nome, telefone, congregacao, data_batismo, data_nascimento, departamento, foto_path
)
  on public.membros to authenticated;

-- Protege matrícula, e-mail, vínculo Auth e status de alterações feitas pelo membro.
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

drop trigger if exists proteger_campos_membro on public.membros;
create trigger proteger_campos_membro
  before update on public.membros
  for each row execute function public.proteger_dados_membro();

-- Vincula cadastros existentes a usuários Auth com o mesmo e-mail.
update public.membros as membro
set usuario_id = usuario.id
from auth.users as usuario
where membro.usuario_id is null
  and lower(membro.email) = lower(usuario.email);

drop policy if exists "Membro consulta proprio cadastro ou admin consulta todos"
  on public.membros;
create policy "Membro consulta proprio cadastro ou admin consulta todos"
  on public.membros for select
  to authenticated
  using (usuario_id = auth.uid() or public.eh_administrador());

drop policy if exists "Admin gerencia cadastros de membros"
  on public.membros;
create policy "Admin gerencia cadastros de membros"
  on public.membros for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

drop policy if exists "Membro altera campos cadastrais permitidos"
  on public.membros;
create policy "Membro altera campos cadastrais permitidos"
  on public.membros for update
  to authenticated
  using (usuario_id = auth.uid() and ativo)
  with check (usuario_id = auth.uid() and ativo);

grant select, insert, update, delete
  on public.departamentos_membros to authenticated;

drop policy if exists "Admins gerenciam equipe dos departamentos"
  on public.departamentos_membros;
create policy "Admins gerenciam equipe dos departamentos"
  on public.departamentos_membros for all
  to authenticated
  using (public.eh_administrador())
  with check (public.eh_administrador());

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

-- Para membros pré-cadastrados entrarem, use no Auth o mesmo e-mail desta tabela.