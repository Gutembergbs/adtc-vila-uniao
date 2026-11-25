do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pedidos_oracao'
  ) then
    alter publication supabase_realtime add table public.pedidos_oracao;
  end if;
end;
$$;
