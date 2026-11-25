do $$
declare
  realtime_table text;
begin
  foreach realtime_table in array array[
    'eventos_agenda',
    'pedidos_oracao',
    'membros',
    'visitantes'
  ]
  loop
    if not exists (
      select 1
      from pg_catalog.pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = realtime_table
    ) then
      execute pg_catalog.format(
        'alter publication supabase_realtime add table public.%I',
        realtime_table
      );
    end if;
  end loop;
end;
$$;
