import 'package:flutter/material.dart';
import '../models/department.dart';
import '../models/schedule_event.dart';
import '../models/announcement.dart';
import '../models/scale_item.dart';
import '../models/pedido_oracao.dart';

class DataService {
  static const String churchName = 'ADTC Vila União';
  static const String churchFullName =
      'Assembleia de Deus Templo Central - Vila União';
  static const String churchCity = 'Sobral - CE';
  static const String churchAddress =
      'Rua Principal, Bairro Vila União, Sobral - CE';
  static const String churchInstagram = '@adtcvilauniao';
  static const String churchInstagramUrl =
      'https://instagram.com/adtcvilauniao';
  static const String churchMapsQuery =
      'Assembleia de Deus Vila Uniao Sobral Ceara';
  static const String churchPhone = '(88) 99200-0000';
  static const String churchPixKey = '88 99300-2992';
  static const String contributionsWhatsAppPhone = '5588993002992';
  static const String churchVerse =
      '"E perseveravam na doutrina dos apóstolos, e na comunhão, e no partir do pão, e nas orações." — Atos 2:42';

  static final List<Department> departments = [
    Department(
      id: 'criancas',
      name: 'Departamento de Crianças',
      conjuntoName: 'Estrela da Manhã',
      description:
          'Ministério dedicado ao acolhimento, discipulado lúdico e crescimento espiritual dos pequeninos de Jesus.',
      responsibilities: [
        'Culto infantil aos domingos às 18h',
        'Ensino bíblico lúdico e memorização de versículos',
        'Ensaios e apresentações do Conjunto Estrela da Manhã',
        'EBD Infantil às terças-feiras às 19h',
      ],
      leaderName: 'Tia Claudiana & Equipe Infantil',
      meetingSchedule: 'Domingo às 18h e Terça às 19h',
      icon: Icons.child_care_rounded,
      color: const Color(0xFFF59E0B),
      tags: ['Crianças', 'Estrela da Manhã', 'EBD Infantil', 'Culto Infantil'],
    ),
    Department(
      id: 'adolescentes',
      name: 'Departamento de Adolescentes',
      conjuntoName: 'Shalom Adonai',
      description:
          'Fortalecendo os adolescentes nos caminhos do Senhor com identidade cristã sólida, amizade bíblica e louvor.',
      responsibilities: [
        'Encontros temáticos e dinâmicas bíblicas',
        'Participação nos cultos e eventos com o Conjunto Shalom Adonai',
        'Discipulado para transição da infância para a mocidade',
        'Evangelismo contextualizado entre adolescentes em Sobral',
      ],
      leaderName: 'Líderes de Adolescentes ADTC',
      meetingSchedule: 'Sábados quinzenais às 17h e Terça às 19h',
      icon: Icons.emoji_people_rounded,
      color: const Color(0xFF06B6D4),
      tags: ['Adolescentes', 'Shalom Adonai', 'Juventude', 'Louvor'],
    ),
    Department(
      id: 'jovens',
      name: 'Departamento de Jovens',
      conjuntoName: 'Celebra',
      description:
          'Uma juventude apaixonada por Deus, cheia do Espírito Santo, comprometida com a santidade e o avivamento em Sobral.',
      responsibilities: [
        'Organização de cultos de mocidade e vigílias de oração',
        'Ensaios e ministração do Conjunto Celebra',
        'Conferências de Jovens e retiros espirituais',
        'Evangelismo urbano nas ruas e praças de Sobral',
      ],
      leaderName: 'Diretoria Celebra ADTC',
      meetingSchedule: 'Sábados às 19h30 e Domingos de Louvor',
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFEF4444),
      tags: ['Jovens', 'Celebra', 'Vigília', 'Avivamento', 'Mocidade'],
    ),
    Department(
      id: 'senhoras',
      name: 'Departamento de Senhoras',
      conjuntoName: 'Filadélfia',
      description:
          'Mulheres guerreiras de joelhos no chão, sustentando a igreja e as famílias em oração e jejum contínuos.',
      responsibilities: [
        'Ensaio de Senhoras todas as segundas-feiras às 18h',
        'Círculo de Oração todas as segundas-feiras às 19h',
        'Visitas aos enfermos e lares necessitados em Sobral',
        'Grande Congresso Anual do Conjunto Filadélfia',
      ],
      leaderName: 'Coordenação do Círculo de Oração',
      meetingSchedule:
          'Segunda-feira às 18h (Ensaio) e 19h (Círculo de Oração)',
      icon: Icons.favorite_rounded,
      color: const Color(0xFFEC4899),
      tags: ['Senhoras', 'Filadélfia', 'Círculo de Oração', 'Intercessão'],
    ),
    Department(
      id: 'obreiros',
      name: 'Departamento de Obreiros',
      conjuntoName: 'Valentes de Davi',
      description:
          'Diáconos, presbíteros, evangelistas e cooperadores dedicados à vigilância, ao serviço santo e à edificação do templo.',
      responsibilities: [
        'Apoio nos trabalhos do altar e púlpito da congregação',
        'Recepção, portaria, segurança e ordem nos cultos',
        'Auxílio na ministração da Santa Ceia do Senhor',
        'Plantão de oração e apoio direto ao pastor dirigente',
      ],
      leaderName: 'Corpo Pastoral & Presbitério',
      meetingSchedule: 'Plantão em todos os cultos e reunião mensal',
      icon: Icons.shield_rounded,
      color: const Color(0xFF3B82F6),
      tags: ['Obreiros', 'Valentes de Davi', 'Diaconato', 'Presbitério'],
    ),
    Department(
      id: 'missoes',
      name: 'Departamento de Missões',
      conjuntoName: null,
      description:
          'O chamado missionário que pulsa no coração da igreja, apoiando obreiros no sertão cearense e até os confins da terra.',
      responsibilities: [
        'Coordenação do Culto de Missões no domingo mensal às 18h',
        'Arrecadação do carnê e coletas missionárias voluntárias',
        'Envio de mantimentos e cartas aos missionários do campo',
        'Feira missionária e oração pelas nações não alcançadas',
      ],
      leaderName: 'Secretaria de Missões ADTC',
      meetingSchedule: 'Culto Mensal no Domingo às 18h',
      icon: Icons.public_rounded,
      color: const Color(0xFF10B981),
      tags: ['Missões', 'Evangelismo', 'Sertão Cearense', 'Povos'],
    ),
    Department(
      id: 'familia',
      name: 'Departamento da Família',
      conjuntoName: null,
      description:
          'Promovendo a restauração, o diálogo bíblico e a santidade nos lares, casamentos e relações entre pais e filhos.',
      responsibilities: [
        'Organização do Culto da Família mensal aos domingos às 18h',
        'Encontros de casais, jantares românticos e palestras temáticas',
        'Aconselhamento matrimonial com princípios bíblicos',
        'Intercessão pelos lares da Vila União em Sobral',
      ],
      leaderName: 'Casal Coordenador de Famílias',
      meetingSchedule: 'Culto da Família no Domingo às 18h',
      icon: Icons.home_rounded,
      color: const Color(0xFF8B5CF6),
      tags: ['Família', 'Casamentos', 'Lares', 'Edificação'],
    ),
    Department(
      id: 'denoc',
      name: 'Departamento de Novos Convertidos',
      conjuntoName: 'DENOC',
      description:
          'Acolhimento amoroso de quem aceita a Cristo, fornecendo discipulado básico, acompanhamento e preparação para o batismo.',
      responsibilities: [
        'Recepção imediata e preenchimento de ficha de decisão no apelo',
        'Classe DENOC na EBD de terça-feira às 19h',
        'Acompanhamento fraterno durante as primeiras semanas de fé',
        'Encaminhamento para as águas batismais da ADTC',
      ],
      leaderName: 'Equipe de Discipulado DENOC',
      meetingSchedule: 'Terça-feira às 19h (EBD) e apoio em todos os cultos',
      icon: Icons.person_add_alt_1_rounded,
      color: const Color(0xFF14B8A6),
      tags: ['DENOC', 'Novos Convertidos', 'Discipulado', 'Batismo'],
    ),
    Department(
      id: 'louvor',
      name: 'Departamento de Louvor',
      conjuntoName: 'Ministério Livres pra Adorar',
      description:
          'Levitas e instrumentistas comprometidos em atrair a presença de Deus por meio do louvor sincero e em espírito e em verdade.',
      responsibilities: [
        'Condução do louvor congregacional em todos os cultos',
        'Ensaios técnicos vocais e instrumentais semanais',
        'Cuidado com a excelência musical e espiritual das canções',
        'Integração com a equipe de som e mídia da igreja',
      ],
      leaderName: 'Ministro de Louvor ADTC',
      meetingSchedule: 'Ensaios nos sábados e cultos oficiais',
      icon: Icons.music_note_rounded,
      color: const Color(0xFF6366F1),
      tags: ['Louvor', 'Livres pra Adorar', 'Banda', 'Vozes', 'Adoração'],
    ),
    Department(
      id: 'midia',
      name: 'Departamento de Mídia & Comunicação',
      conjuntoName: null,
      description:
          'A voz e imagem da congregação no meio digital e presencial. Responsável por gravações, redes sociais, projeção e som.',
      responsibilities: [
        'Gravação e transmissão ao vivo dos cultos e eventos',
        'Postagens, stories e avisos no Instagram oficial (@adtcvilauniao)',
        'Projeção de letras de louvores, avisos e versículos no telão',
        'Iluminação cênica, fotografia e cobertura dos congressos',
      ],
      leaderName: 'Equipe de Mídia & Redes',
      meetingSchedule: 'Operação em todos os cultos e reuniões de mídia',
      icon: Icons.camera_alt_rounded,
      color: const Color(0xFF0284C7),
      tags: ['Mídia', 'Instagram', 'Projeção', 'Gravação', 'Transmissão'],
      instagram: '@adtcvilauniao',
    ),
  ];

  static final List<ScheduleEvent> scheduleEvents = [
    // Daily noon prayer
    ScheduleEvent(
      id: 'oracao_meio_dia',
      title: 'Oração do Meio-Dia',
      subtitle: 'Intercessão Diária da Igreja',
      time: '12:00',
      daysDescription: 'Segunda a Domingo (Todos os dias)',
      dayOfWeek: null,
      location: 'Templo ADTC Vila União & Corrente de Oração',
      type: EventType.oracao,
      recurringCycle: 'Diário',
      icon: Icons.access_time_filled_rounded,
      color: const Color(0xFFF59E0B),
      notes:
          'Momento diário de busca ao Senhor, onde toda a igreja se une ao meio-dia para clamar pelas famílias, enfermos e congregação.',
    ),

    // Segunda-feira
    ScheduleEvent(
      id: 'seg_ensaio_senhoras',
      title: 'Ensaio de Senhoras',
      subtitle: 'Conjunto Filadélfia',
      time: '18:00',
      daysDescription: 'Toda Segunda-feira',
      dayOfWeek: DateTime.monday,
      location: 'Templo ADTC Vila União',
      type: EventType.ensaio,
      departmentId: 'senhoras',
      recurringCycle: 'Semanal',
      icon: Icons.music_note_rounded,
      color: const Color(0xFFEC4899),
      notes:
          'Ensaio vocal e preparação espiritual do Conjunto de Senhoras Filadélfia antes do Círculo de Oração.',
    ),
    ScheduleEvent(
      id: 'seg_circulo_oracao',
      title: 'Círculo de Oração',
      subtitle: 'Departamento de Senhoras Filadélfia',
      time: '19:00',
      daysDescription: 'Toda Segunda-feira',
      dayOfWeek: DateTime.monday,
      location: 'Templo ADTC Vila União',
      type: EventType.oracao,
      departmentId: 'senhoras',
      recurringCycle: 'Semanal',
      icon: Icons.volunteer_activism_rounded,
      color: const Color(0xFFBE185D),
      notes:
          'Culto fervoroso de clamor, libertação, oração pelas causas impossíveis e testemunhos de milagres.',
    ),

    // Terça-feira
    ScheduleEvent(
      id: 'ter_ebd',
      title: 'EBD - Escola Bíblica Dominical',
      subtitle: 'Estudo das Lições Bíblicas para todas as idades',
      time: '19:00',
      daysDescription: 'Toda Terça-feira',
      dayOfWeek: DateTime.tuesday,
      location: 'Salas e Templo ADTC Vila União',
      type: EventType.estudo,
      recurringCycle: 'Semanal',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF2563EB),
      notes:
          'Classes divididas por faixas etárias: Crianças (Estrela da Manhã), Adolescentes (Shalom Adonai), Jovens (Celebra), Adultos e Classe DENOC (Novos Convertidos).',
    ),

    // Quarta-feira
    ScheduleEvent(
      id: 'qua_consagracao',
      title: 'Consagração Matutina',
      subtitle: 'Oração, Jejum e Busca Espiritual',
      time: '07:30',
      daysDescription: 'Toda Quarta-feira',
      dayOfWeek: DateTime.wednesday,
      location: 'Templo ADTC Vila União',
      type: EventType.consagracao,
      recurringCycle: 'Semanal',
      icon: Icons.wb_sunny_rounded,
      color: const Color(0xFF0D9488),
      notes:
          'Manhã consagrada a Deus com oração fervorosa, jejum individual e leitura da Palavra.',
    ),

    // Quinta-feira
    ScheduleEvent(
      id: 'qui_culto_doutrina',
      title: 'Culto de Doutrina',
      subtitle: 'Ensino Aprofundado da Palavra de Deus',
      time: '19:00',
      daysDescription: 'Toda Quinta-feira',
      dayOfWeek: DateTime.thursday,
      location: 'Templo ADTC Vila União',
      type: EventType.culto,
      recurringCycle: 'Semanal',
      icon: Icons.auto_stories_rounded,
      color: const Color(0xFF4F46E5),
      notes:
          'Estudo bíblico expositivo conduzido pelo pastor dirigente para edificar e instruir a igreja nas santas doutrinas.',
    ),

    // Sexta-feira
    ScheduleEvent(
      id: 'sex_consagracao',
      title: 'Consagração Matutina',
      subtitle: 'Oração, Jejum e Intercessão',
      time: '07:30',
      daysDescription: 'Toda Sexta-feira',
      dayOfWeek: DateTime.friday,
      location: 'Templo ADTC Vila União',
      type: EventType.consagracao,
      recurringCycle: 'Semanal',
      icon: Icons.wb_sunny_rounded,
      color: const Color(0xFF0D9488),
      notes:
          'Segunda consagração da semana para buscar renovo espiritual e bênçãos para o final de semana.',
    ),
    ScheduleEvent(
      id: 'sex_doutrina_sede',
      title: 'Culto de Doutrina na Sede',
      subtitle: 'Reunião Congregacional na Sede em Sobral',
      time: '19:00',
      daysDescription: 'Toda Sexta-feira',
      dayOfWeek: DateTime.friday,
      location: 'ADTC Templo Central - Sede Sobral',
      type: EventType.culto,
      recurringCycle: 'Semanal',
      icon: Icons.apartment_rounded,
      color: const Color(0xFF1E293B),
      notes:
          'Encontro fraterno de todas as congregações no Templo Central da ADTC em Sobral para ministração pastoral geral.',
    ),

    // Sábado
    ScheduleEvent(
      id: 'sab_ensaios_jovens',
      title: 'Ensaios e Programações Especiais',
      subtitle: 'Juventude Celebra & Ministério Livres pra Adorar',
      time: '19:00',
      daysDescription: 'Sábados',
      dayOfWeek: DateTime.saturday,
      location: 'Templo ADTC Vila União',
      type: EventType.ensaio,
      recurringCycle: 'Semanal',
      icon: Icons.groups_rounded,
      color: const Color(0xFF7C3AED),
      notes:
          'Ensaios gerais, vigílias e programações com os jovens do Celebra e adolescentes do Shalom Adonai.',
    ),

    // Domingo - 18h
    ScheduleEvent(
      id: 'dom_culto_celebracao',
      title: 'Culto de Celebração de Domingo',
      subtitle: 'Cultos Acontecem às 18h (Agenda Mensal)',
      time: '18:00',
      daysDescription: 'Todo Domingo às 18h',
      dayOfWeek: DateTime.sunday,
      location: 'Templo ADTC Vila União',
      type: EventType.culto,
      recurringCycle: 'Semanal / Mensal',
      icon: Icons.church_rounded,
      color: const Color(0xFF0F172A),
      notes:
          'O grande culto dominical às 18h com revezamento da agenda mensal: Culto de Santa Ceia, Culto de Missões, Culto da Família e Culto de Louvor e Adoração.',
    ),
  ];

  static final List<ScheduleEvent> monthlySundayThemes = [
    ScheduleEvent(
      id: 'dom_1_santa_ceia',
      title: 'Culto de Santa Ceia do Senhor',
      subtitle: '1º Domingo do Mês às 18h',
      time: '18:00',
      daysDescription: '1º Domingo do Mês',
      dayOfWeek: DateTime.sunday,
      location: 'Templo ADTC Vila União',
      type: EventType.culto,
      recurringCycle: '1º Domingo',
      icon: Icons.wine_bar_rounded,
      color: const Color(0xFF991B1B),
      notes:
          'Memorial solene do sacrifício de Cristo na cruz, comunhão fraterna de toda a congregação e ministração da Ceia pelo pastor e obreiros.',
      monthlyTheme: true,
    ),
    ScheduleEvent(
      id: 'dom_2_missoes',
      title: 'Culto de Missões',
      subtitle: '2º Domingo do Mês às 18h',
      time: '18:00',
      daysDescription: '2º Domingo do Mês',
      dayOfWeek: DateTime.sunday,
      location: 'Templo ADTC Vila União',
      type: EventType.missao,
      recurringCycle: '2º Domingo',
      icon: Icons.public_rounded,
      color: const Color(0xFF059669),
      notes:
          'Culto com foco evangelístico e missionário, testemunhos dos campos do sertão cearense e conscientização da Grande Comissão.',
      monthlyTheme: true,
    ),
    ScheduleEvent(
      id: 'dom_3_familia',
      title: 'Culto da Família',
      subtitle: '3º Domingo do Mês às 18h',
      time: '18:00',
      daysDescription: '3º Domingo do Mês',
      dayOfWeek: DateTime.sunday,
      location: 'Templo ADTC Vila União',
      type: EventType.culto,
      recurringCycle: '3º Domingo',
      icon: Icons.family_restroom_rounded,
      color: const Color(0xFF7C3AED),
      notes:
          'Culto dedicado à oração pelas famílias da Vila União e de Sobral, renovação de alianças no casamento e bênção sobre os filhos.',
      monthlyTheme: true,
    ),
    ScheduleEvent(
      id: 'dom_4_louvor_jovens',
      title: 'Culto de Louvor & Adoração (Celebra)',
      subtitle: '4º Domingo do Mês às 18h',
      time: '18:00',
      daysDescription: '4º Domingo do Mês',
      dayOfWeek: DateTime.sunday,
      location: 'Templo ADTC Vila União',
      type: EventType.culto,
      recurringCycle: '4º Domingo',
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFFDC2626),
      notes:
          'Noite vibrante de louvor e exaltação ao Senhor com o Ministério Livres pra Adorar, Juventude Celebra e Adolescentes Shalom Adonai.',
      monthlyTheme: true,
    ),
  ];

  static final List<ScaleItem> scales = [
    ScaleItem(
      id: 'scale_1',
      serviceName: 'Culto de Domingo às 18h',
      date: 'Próximo Domingo',
      time: '18:00',
      department: 'Departamento de Mídia',
      volunteers: [
        'Mateus Silva (Transmissão & Gravação)',
        'Lucas Rocha (Projeção & Telão)',
        'Vitória Albuquerque (Stories & Instagram)',
      ],
      observation: 'Chegar às 17h15 para teste de áudio, slides e cabos.',
    ),
    ScaleItem(
      id: 'scale_2',
      serviceName: 'Culto de Domingo às 18h',
      date: 'Próximo Domingo',
      time: '18:00',
      department: 'Ministério Livres pra Adorar',
      volunteers: [
        'Gabriel (Vocal & Violão)',
        'Renata (Vocal Principal)',
        'Davi (Teclado)',
        'Samuel (Bateria)',
        'Elias (Baixo)',
      ],
      observation: 'Passagem de som às 17h em ponto.',
    ),
    ScaleItem(
      id: 'scale_3',
      serviceName: 'Culto de Domingo às 18h',
      date: 'Próximo Domingo',
      time: '18:00',
      department: 'Valentes de Davi (Obreiros & Recepção)',
      volunteers: [
        'Pb. Francisco (Direção do Culto)',
        'Dc. Raimundo (Portaria e Acolhimento)',
        'Dc. Antônio (Apoio Altar)',
        'Ir. Marcos (Recepção de Visitantes)',
      ],
      observation: 'Entrega de fichas de visitantes na recepção.',
    ),
    ScaleItem(
      id: 'scale_4',
      serviceName: 'Segunda-feira - Círculo de Oração',
      date: 'Próxima Segunda',
      time: '19:00',
      department: 'Departamento de Senhoras Filadélfia',
      volunteers: [
        'Ir. Maria das Graças (Direção do Louvor)',
        'Ir. Antônia (Palavra de Exortação)',
        'Equipe de Intercessão das 18h',
      ],
      observation: 'Ensaio pontual às 18h antes da reunião de oração.',
    ),
    ScaleItem(
      id: 'scale_5',
      serviceName: 'Terça-feira - EBD',
      date: 'Próxima Terça',
      time: '19:00',
      department: 'Corpo Docente EBD',
      volunteers: [
        'Prof. Josué (Classe de Adultos)',
        'Prof. Luan (Classe Jovens Celebra)',
        'Tia Sara (Estrela da Manhã)',
        'Ir. Carlos (Classe DENOC)',
      ],
      observation: 'Trazer revistas da lição bíblica atual.',
    ),
  ];

  static final List<Announcement> announcements = [
    Announcement(
      id: 'aviso_1',
      title: 'Cultos de Domingo às 18h - Traga sua Família!',
      summary:
          'Lembramos a todos os irmãos que o culto de domingo agora acontece pontualmente às 18h.',
      content:
          'Querida congregação ADTC Vila União, nosso grande culto dominical de celebração inicia pontualmente às 18h. Chegue com antecedência para oração e louvor. Se você tem vizinhos ou parentes, convide-os para estarem conosco!',
      date: 'Esta Semana',
      category: 'Aviso Geral',
      isMembersOnly: false,
    ),
    Announcement(
      id: 'aviso_2',
      title: 'Corrente da Oração do Meio-Dia (Seg a Dom)',
      summary:
          'Diariamente das 12:00 às 12:30 clamando pelas causas da igreja e cura de enfermos.',
      content:
          'Onde você estiver — no trabalho, em casa ou no templo — pare às 12h para se unir em um só espírito com a ADTC Vila União. Deus tem operado maravilhas através desta oração contínua.',
      date: 'Contínuo',
      category: 'Oração',
      isMembersOnly: false,
    ),
    Announcement(
      id: 'aviso_3',
      title: 'Escala de Mídia e Projeção Atualizada',
      summary:
          'A equipe de mídia divulgou a nova escala para os cultos de terça, quinta e domingo.',
      content:
          'Irmãos escalados na projeção e som devem confirmar presença no grupo oficial de comunicação até sexta-feira ao meio-dia. Deus abençoe esse ministério essencial!',
      date: 'Hoje',
      category: 'Escala',
      isMembersOnly: true,
    ),
    Announcement(
      id: 'aviso_4',
      title: 'Discipulado DENOC - Turma de Batismo',
      summary:
          'Novos convertidos estão convidados para a aula especial nesta terça-feira às 19h.',
      content:
          'O Departamento de Novos Convertidos (DENOC) informa que as inscrições para as aulas pré-batismo estão abertas. Procure a liderança no final do culto.',
      date: 'Ontem',
      category: 'DENOC',
      isMembersOnly: true,
    ),
  ];

  // Pedidos demonstrativos exibidos quando o Supabase não está configurado.
  static final List<PedidoOracao> pedidosIniciaisOracao = [
    PedidoOracao(
      identificador: 'p1',
      nomeAutor: 'Ir. Francisca Lima',
      pedido:
          'Peço oração pela restauração da saúde de minha mãe e pela conversão dos meus dois filhos.',
      categoria: 'Família',
      dataCriacao: DateTime.now().subtract(const Duration(hours: 4)),
      quantidadeOracoes: 14,
    ),
    PedidoOracao(
      identificador: 'p2',
      nomeAutor: 'Visitante Marcos',
      pedido:
          'Estive no culto de domingo às 18h e peço oração por uma porta de emprego aqui em Sobral.',
      categoria: 'Emprego',
      dataCriacao: DateTime.now().subtract(const Duration(hours: 9)),
      quantidadeOracoes: 22,
    ),
    PedidoOracao(
      identificador: 'p3',
      nomeAutor: 'Equipe de Missões',
      pedido:
          'Clamor pelos obreiros no interior do Ceará e pelos preparativos do próximo Culto de Missões.',
      categoria: 'Espiritual',
      dataCriacao: DateTime.now().subtract(const Duration(days: 1)),
      quantidadeOracoes: 31,
    ),
    PedidoOracao(
      identificador: 'p4',
      nomeAutor: 'Anonimamente',
      pedido:
          'Agradecimento a Deus por livramento concedido na estrada e pedido de paz no meu lar.',
      categoria: 'Gratidão',
      dataCriacao: DateTime.now().subtract(const Duration(days: 2)),
      quantidadeOracoes: 18,
      anonimo: true,
    ),
  ];
}
