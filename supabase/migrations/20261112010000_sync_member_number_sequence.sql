do $migration$
declare
  sequence_name text;
  sequence_last_value bigint;
  sequence_is_called boolean;
  largest_member_number bigint;
begin
  sequence_name := pg_get_serial_sequence('public.membros', 'matricula');
  if sequence_name is null then
    raise exception 'Não foi encontrada a sequência da matrícula de membros.';
  end if;

  execute format(
    'select last_value, is_called from %s',
    sequence_name
  )
  into sequence_last_value, sequence_is_called;

  select coalesce(max(matricula), 0)
    into largest_member_number
  from public.membros;

  if largest_member_number > sequence_last_value
    or (
      largest_member_number = sequence_last_value
      and not sequence_is_called
      and largest_member_number > 0
    ) then
    perform setval(sequence_name::regclass, largest_member_number, true);
  end if;
end;
$migration$;
