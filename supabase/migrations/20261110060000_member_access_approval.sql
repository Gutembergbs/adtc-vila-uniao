alter table public.membros
  add column if not exists status_acesso text not null default 'autorizado';

update public.membros
set status_acesso = case
  when ativo then 'autorizado'
  else 'bloqueado'
end
where status_acesso not in ('pendente', 'autorizado', 'bloqueado')
  or (status_acesso = 'autorizado' and not ativo);

alter table public.membros
  drop constraint if exists membros_status_acesso_check;

alter table public.membros
  add constraint membros_status_acesso_check
  check (status_acesso in ('pendente', 'autorizado', 'bloqueado'));

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
      or new.status_acesso is distinct from old.status_acesso
      or new.criado_em is distinct from old.criado_em
    ) then
    raise exception 'Campos restritos do cadastro não podem ser alterados pelo membro.';
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

drop policy if exists "Admins leem fotos de membros"
  on storage.objects;
create policy "Admins leem fotos de membros"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and public.eh_administrador()
  );

drop policy if exists "Membros ativos leem sua propria foto"
  on storage.objects;
drop policy if exists "Membros leem sua propria foto"
  on storage.objects;
create policy "Membros ativos leem sua propria foto"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1
      from public.membros as membro
      where membro.usuario_id = auth.uid()
        and membro.ativo
    )
  );

drop policy if exists "Membros enviam sua propria foto"
  on storage.objects;
drop policy if exists "Membros ativos enviam sua propria foto"
  on storage.objects;
create policy "Membros ativos enviam sua propria foto"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1
      from public.membros as membro
      where membro.usuario_id = auth.uid()
        and membro.ativo
    )
  );

drop policy if exists "Membros atualizam sua propria foto"
  on storage.objects;
drop policy if exists "Membros ativos atualizam sua propria foto"
  on storage.objects;
create policy "Membros ativos atualizam sua propria foto"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1
      from public.membros as membro
      where membro.usuario_id = auth.uid()
        and membro.ativo
    )
  )
  with check (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1
      from public.membros as membro
      where membro.usuario_id = auth.uid()
        and membro.ativo
    )
  );

drop policy if exists "Membros removem sua propria foto"
  on storage.objects;
drop policy if exists "Membros ativos removem sua propria foto"
  on storage.objects;
create policy "Membros ativos removem sua propria foto"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1
      from public.membros as membro
      where membro.usuario_id = auth.uid()
        and membro.ativo
    )
  );
