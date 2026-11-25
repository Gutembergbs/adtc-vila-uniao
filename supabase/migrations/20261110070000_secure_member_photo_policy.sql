create or replace function public.usuario_atual_pode_gerenciar_foto()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.membros as membro
    where membro.usuario_id = auth.uid()
      and membro.ativo
      and membro.status_acesso = 'autorizado'
  );
$$;

revoke all on function public.usuario_atual_pode_gerenciar_foto()
  from public, anon;
grant execute on function public.usuario_atual_pode_gerenciar_foto()
  to authenticated;

drop policy if exists "Membros ativos leem sua propria foto"
  on storage.objects;
create policy "Membros ativos leem sua propria foto"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.usuario_atual_pode_gerenciar_foto()
  );

drop policy if exists "Membros ativos enviam sua propria foto"
  on storage.objects;
create policy "Membros ativos enviam sua propria foto"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.usuario_atual_pode_gerenciar_foto()
  );

drop policy if exists "Membros ativos atualizam sua propria foto"
  on storage.objects;
create policy "Membros ativos atualizam sua propria foto"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.usuario_atual_pode_gerenciar_foto()
  )
  with check (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.usuario_atual_pode_gerenciar_foto()
  );

drop policy if exists "Membros ativos removem sua propria foto"
  on storage.objects;
create policy "Membros ativos removem sua propria foto"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'fotos-membros'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.usuario_atual_pode_gerenciar_foto()
  );
