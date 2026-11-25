-- Dados fictícios para testar a administração. E-mails .test não recebem mensagens.
insert into public.membros (
  email,
  nome,
  telefone,
  departamento,
  congregacao,
  data_nascimento,
  data_batismo,
  ativo
)
values
  (
    'ana.souza@example.test',
    'TESTE - Ana Souza',
    '(88) 90000-0001',
    '',
    'ADTC Vila União - Sobral',
    '1992-04-15',
    '2012-06-10',
    true
  ),
  (
    'bruno.lima@example.test',
    'TESTE - Bruno Lima',
    '(88) 90000-0002',
    '',
    'ADTC Vila União - Sobral',
    '1988-09-22',
    '2008-11-02',
    true
  ),
  (
    'carla.mendes@example.test',
    'TESTE - Carla Mendes',
    '(88) 90000-0003',
    '',
    'ADTC Vila União - Sobral',
    '1997-01-08',
    '2018-03-25',
    true
  ),
  (
    'diego.rocha@example.test',
    'TESTE - Diego Rocha',
    '(88) 90000-0004',
    '',
    'ADTC Vila União - Sobral',
    '1990-12-03',
    '2010-08-01',
    true
  ),
  (
    'elisa.costa@example.test',
    'TESTE - Elisa Costa',
    '(88) 90000-0005',
    '',
    'ADTC Vila União - Sobral',
    '2001-07-19',
    null,
    true
  ),
  (
    'felipe.alves@example.test',
    'TESTE - Felipe Alves',
    '(88) 90000-0006',
    '',
    'ADTC Vila União - Sobral',
    '1995-02-11',
    null,
    true
  ),
  (
    'gabriela.nunes@example.test',
    'TESTE - Gabriela Nunes',
    '(88) 90000-0007',
    '',
    'ADTC Vila União - Sobral',
    '2003-03-26',
    null,
    true
  ),
  (
    'heitor.moura@example.test',
    'TESTE - Heitor Moura',
    '(88) 90000-0008',
    '',
    'ADTC Vila União - Sobral',
    '1994-05-04',
    null,
    true
  ),
  (
    'isabela.pires@example.test',
    'TESTE - Isabela Pires',
    '(88) 90000-0009',
    '',
    'ADTC Vila União - Sobral',
    '1989-06-17',
    null,
    true
  ),
  (
    'joao.santos@example.test',
    'TESTE - João Santos',
    '(88) 90000-0010',
    '',
    'ADTC Vila União - Sobral',
    '2000-08-29',
    null,
    true
  ),
  (
    'larissa.oliveira@example.test',
    'TESTE - Larissa Oliveira',
    '(88) 90000-0011',
    '',
    'ADTC Vila União - Sobral',
    '1993-10-12',
    null,
    true
  ),
  (
    'marcos.ribeiro@example.test',
    'TESTE - Marcos Ribeiro',
    '(88) 90000-0012',
    '',
    'ADTC Vila União - Sobral',
    '1985-11-06',
    null,
    true
  ),
  (
    'nathalia.farias@example.test',
    'TESTE - Nathalia Farias',
    '(88) 90000-0013',
    '',
    'ADTC Vila União - Sobral',
    '1998-04-02',
    null,
    true
  ),
  (
    'otavio.lopes@example.test',
    'TESTE - Otávio Lopes',
    '(88) 90000-0014',
    '',
    'ADTC Vila União - Sobral',
    '1991-12-19',
    null,
    true
  ),
  (
    'rafaela.dias@example.test',
    'TESTE - Rafaela Dias',
    '(88) 90000-0015',
    '',
    'ADTC Vila União - Sobral',
    '2002-01-30',
    null,
    true
  )
on conflict (email) do nothing;
