alter table public.eventos_agenda
  add column if not exists link_texto text,
  add column if not exists link_url text;
