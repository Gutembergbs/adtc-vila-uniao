import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../configuracao_supabase.dart';
import '../services/agenda_notification_service.dart';
import '../services/data_service.dart';
import '../services/content_service.dart';
import '../services/church_share_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_navigation_actions.dart';
import '../utils/calendar_date_utils.dart';
import '../models/schedule_event.dart';
import '../widgets/event_attachment_actions.dart';
import '../widgets/event_attachment_preview.dart';
import 'schedule_event_details_screen.dart';

class ScheduleScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onOpenDrawer;
  final VoidCallback onLoginRequired;
  final ScheduleEvent? eventToOpen;
  final String? eventIdToOpen;
  final VoidCallback onEventRequestHandled;

  const ScheduleScreen({
    super.key,
    required this.authService,
    required this.onOpenDrawer,
    required this.onLoginRequired,
    required this.eventToOpen,
    required this.eventIdToOpen,
    required this.onEventRequestHandled,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

enum _CalendarMode { month, week }

class _ScheduleScreenState extends State<ScheduleScreen> {
  _CalendarMode _calendarMode = _CalendarMode.month;
  DateTime _calendarDate = DateTime.now();
  DateTime _selectedCalendarDay = DateTime.now();
  List<ScheduleEvent> _events = [];
  bool _loading = true;
  bool? _realtimeConnected;
  String? _realtimeError;
  RealtimeChannel? _agendaChannel;
  final Map<String, Future<String>> _attachmentUrls = {};
  final Map<String, DateTime> _attachmentUrlCreatedAt = {};
  String? _openedEventRequestId;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _subscribeToAgendaChanges();
  }

  @override
  void didUpdateWidget(covariant ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventToOpen == null && widget.eventIdToOpen == null) {
      _openedEventRequestId = null;
    } else if (oldWidget.eventToOpen?.id != widget.eventToOpen?.id ||
        oldWidget.eventIdToOpen != widget.eventIdToOpen) {
      _openRequestedEvent();
    }
  }

  /// Busca a programação no banco e conserva a agenda de demonstração offline.
  Future<void> _loadEvents() async {
    try {
      final events = await ContentService.listScheduleEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
        _attachmentUrls.clear();
        _attachmentUrlCreatedAt.clear();
      });
      _openRequestedEvent();
      unawaited(AgendaNotificationService.sincronizarLembretes(events));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _events = [
          ...DataService.scheduleEvents,
          ...DataService.monthlySundayThemes,
        ];
        _loading = false;
        _attachmentUrls.clear();
        _attachmentUrlCreatedAt.clear();
      });
      _openRequestedEvent();
      unawaited(AgendaNotificationService.sincronizarLembretes(_events));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar a agenda.')),
      );
    }
  }

  /// Observa alterações Supabase enquanto a agenda estiver aberta.
  void _subscribeToAgendaChanges() {
    if (!supabaseInicializado) {
      return;
    }

    _agendaChannel = Supabase.instance.client
        .channel('agenda-publica-alteracoes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'eventos_agenda',
          callback: _onAgendaChanged,
        )
        .subscribe((status, erro) {
          if (!mounted) return;
          setState(() {
            _realtimeConnected = status == RealtimeSubscribeStatus.subscribed;
            _realtimeError = erro?.toString();
          });
        });
  }

  /// Atualiza a agenda em tempo real sem notificar a cada salvamento.
  void _onAgendaChanged(PostgresChangePayload _) {
    unawaited(_loadEvents());
  }

  @override
  void dispose() {
    final channel = _agendaChannel;
    if (channel != null && supabaseInicializado) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  void _shareEvent(ScheduleEvent event) {
    final date = event.eventDate;
    final dateText = date == null
        ? event.daysDescription
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    ChurchShareService.chooseShareMode(
      context,
      title: event.title,
      text:
          '$dateText • ${event.time}\n${event.subtitle}\nLocal: ${event.location}\n\n${event.notes}',
    );
  }

  void _openRequestedEvent() {
    final requestId = widget.eventToOpen?.id ?? widget.eventIdToOpen;
    ScheduleEvent? event = widget.eventToOpen;
    if (event == null && widget.eventIdToOpen != null) {
      for (final candidate in _events) {
        if (candidate.id == widget.eventIdToOpen) {
          event = candidate;
          break;
        }
      }
    }
    if (_loading ||
        requestId == null ||
        _openedEventRequestId == requestId ||
        !mounted) {
      return;
    }

    _openedEventRequestId = requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onEventRequestHandled();
      if (event == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este evento não está mais disponível na agenda.'),
          ),
        );
        return;
      }
      _showEventDetails(event);
    });
  }

  Future<String> _eventAttachmentUrl(ScheduleEvent event) {
    final path = event.attachmentPath!;
    final createdAt = _attachmentUrlCreatedAt[event.id];
    if (createdAt != null &&
        DateTime.now().difference(createdAt) >= const Duration(minutes: 4)) {
      _attachmentUrls.remove(event.id);
      _attachmentUrlCreatedAt.remove(event.id);
    }
    return _attachmentUrls.putIfAbsent(event.id, () {
      _attachmentUrlCreatedAt[event.id] = DateTime.now();
      return ContentService.createEventAttachmentUrl(path);
    });
  }

  void _showEventDetails(ScheduleEvent event, {DateTime? selectedDate}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScheduleEventDetailsScreen(
          event: event,
          selectedDate: selectedDate,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppNavigationMenuButton(
          onPressed: widget.onOpenDrawer,
          showBackButton: true,
          user: widget.authService.isAuthenticated
              ? widget.authService.currentUser
              : null,
        ),
        title: const Text('Agenda e Programação'),
        actions: [
          if (supabaseInicializado) _buildRealtimeStatus(),
          AppNotificationsAction(
            authService: widget.authService,
            onLoginRequired: widget.onLoginRequired,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildCalendarTab(),
    );
  }

  Widget _buildRealtimeStatus() {
    final connected = _realtimeConnected == true;
    final connecting = _realtimeConnected == null;
    final color = connected
        ? const Color(0xFF15803D)
        : connecting
        ? const Color(0xFFB45309)
        : const Color(0xFFB42318);
    final label = connected
        ? 'Conectado em tempo real'
        : connecting
        ? 'Conectando ao Realtime'
        : 'Realtime desconectado';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: _realtimeError == null ? label : '$label: $_realtimeError',
        child: Icon(
          connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    final title = _calendarMode == _CalendarMode.month
        ? '${_monthNames[_calendarDate.month - 1]} ${_calendarDate.year}'
        : '${_formatCalendarDate(_weekStart(_calendarDate))} – ${_formatCalendarDate(_weekStart(_calendarDate).add(const Duration(days: 6)))}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850;
        return Padding(
          padding: EdgeInsets.all(wide ? 20 : 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Programação da congregação',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SegmentedButton<_CalendarMode>(
                segments: const [
                  ButtonSegment(value: _CalendarMode.month, label: Text('Mês')),
                  ButtonSegment(
                    value: _CalendarMode.week,
                    label: Text('Semana'),
                  ),
                ],
                selected: {_calendarMode},
                onSelectionChanged: (selection) {
                  final mode = selection.first;
                  setState(() {
                    _calendarMode = mode;
                    _calendarDate = mode == _CalendarMode.week
                        ? _selectedCalendarDay
                        : DateTime(
                            _selectedCalendarDay.year,
                            _selectedCalendarDay.month,
                          );
                  });
                },
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: _calendarMode == _CalendarMode.month
                        ? 'Mês anterior'
                        : 'Semana anterior',
                    onPressed: () => _moveCalendar(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final today = DateTime.now();
                      setState(() {
                        _calendarDate = today;
                        _selectedCalendarDay = today;
                      });
                    },
                    child: const Text('Hoje'),
                  ),
                  IconButton(
                    tooltip: _calendarMode == _CalendarMode.month
                        ? 'Próximo mês'
                        : 'Próxima semana',
                    onPressed: () => _moveCalendar(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              Expanded(
                child: wide && _calendarMode == _CalendarMode.month
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 440,
                            child: _calendarMode == _CalendarMode.month
                                ? _buildMonthCalendar()
                                : _buildWeekCalendar(),
                          ),
                          const VerticalDivider(width: 28),
                          Expanded(
                            child: _buildSelectedDayEvents(
                              _selectedCalendarDay,
                              scrollable: true,
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            if (_calendarMode == _CalendarMode.month)
                              SizedBox(
                                height: 270,
                                child: _buildMonthCalendar(),
                              )
                            else
                              _buildWeekCalendar(),
                            const Divider(height: 1),
                            _buildSelectedDayEvents(
                              _selectedCalendarDay,
                              scrollable: false,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static const _monthWeekDayInitials = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
  static const _weekDayNames = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  void _moveCalendar(int amount) {
    setState(() {
      _calendarDate = switch (_calendarMode) {
        _CalendarMode.month => DateTime(
          _calendarDate.year,
          _calendarDate.month + amount,
          1,
        ),
        _CalendarMode.week => _calendarDate.add(Duration(days: amount * 7)),
      };
      if (_calendarMode == _CalendarMode.week) {
        _selectedCalendarDay = _weekStart(_calendarDate);
      } else if (_selectedCalendarDay.year != _calendarDate.year ||
          _selectedCalendarDay.month != _calendarDate.month) {
        _selectedCalendarDay = DateTime(
          _calendarDate.year,
          _calendarDate.month,
          1,
        );
      }
    });
  }

  Widget _buildMonthCalendar() {
    final cells = monthCalendarDates(_calendarDate);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: _monthWeekDayInitials
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 38,
          ),
          itemBuilder: (context, index) {
            final date = cells[index];
            if (date == null) return const SizedBox.shrink();
            final eventCount = _eventsForDate(date).length;
            final selected = _sameDay(date, _selectedCalendarDay);
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedCalendarDay = date),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0F766E) : null,
                  borderRadius: BorderRadius.circular(10),
                  border: !selected && _sameDay(date, DateTime.now())
                      ? Border.all(color: const Color(0xFF0F766E))
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        fontWeight: selected || eventCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (eventCount > 0)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFD97706),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeekCalendar() {
    final start = _weekStart(_calendarDate);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 7
            : constraints.maxWidth >= 500
            ? 3
            : 2;
        final cardWidth = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (index) {
            final date = start.add(Duration(days: index));
            final events = _eventsForDate(date);
            final selected = _sameDay(date, _selectedCalendarDay);
            return SizedBox(
              width: cardWidth,
              child: Card(
                margin: EdgeInsets.zero,
                color: selected ? const Color(0xFFE5F3F0) : null,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _selectedCalendarDay = date),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _weekDayNames[index],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (events.isEmpty)
                          const Text(
                            'Sem eventos',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          )
                        else
                          ...events.map(
                            (event) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                '${event.time} · ${event.title}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: event.color,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSelectedDayEvents(DateTime date, {required bool scrollable}) {
    final events = _eventsForDate(date);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatCalendarDate(date),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Text('Nenhum evento neste dia.')
        else
          ...events.map((event) => _buildEventCard(event, selectedDate: date)),
      ],
    );
    return scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.only(top: 4),
            child: content,
          )
        : content;
  }

  List<ScheduleEvent> _eventsForDate(DateTime date) {
    final events = _events.where((event) {
      if (event.eventDate != null) {
        return _sameDay(event.eventDate!, date);
      }
      if (event.monthlyTheme) {
        if (date.weekday != DateTime.sunday) return false;
        final cycle = event.recurringCycle;
        final ordinal = cycle == null || cycle.isEmpty
            ? null
            : int.tryParse(cycle.substring(0, 1));
        return ordinal == null || ((date.day - 1) ~/ 7) + 1 == ordinal;
      }
      return event.dayOfWeek == null || event.dayOfWeek == date.weekday;
    }).toList();
    events.sort(ScheduleEvent.compareByTime);
    return events;
  }

  DateTime _weekStart(DateTime date) =>
      DateTime(date.year, date.month, date.day - date.weekday + 1);

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  String _formatCalendarDate(DateTime date) =>
      '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

  Widget _buildEventCard(ScheduleEvent event, {DateTime? selectedDate}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: event.color.withAlpha(40)),
      ),
      child: InkWell(
        onTap: () => _showEventDetails(event, selectedDate: selectedDate),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: event.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(event.icon, color: event.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          event.subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2540),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.time,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.authService.hasApprovedMemberAccess &&
                  event.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  event.notes,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade800,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    tooltip: 'Compartilhar',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _shareEvent(event),
                  ),
                ],
              ),
              if (event.attachmentPath != null &&
                  widget.authService.hasApprovedMemberAccess) ...[
                const SizedBox(height: 8),
                EventAttachmentPreview(
                  event: event,
                  loadUrl: () => _eventAttachmentUrl(event),
                ),
                const SizedBox(height: 8),
                EventAttachmentActions(event: event),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
