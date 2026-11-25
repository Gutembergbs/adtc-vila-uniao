import 'dart:async';

import 'package:flutter/material.dart';

import '../models/schedule_event.dart';
import '../services/content_service.dart';
import '../services/data_service.dart';

class NextServiceCard extends StatefulWidget {
  final ValueChanged<ScheduleEvent> onOpenEvent;

  const NextServiceCard({super.key, required this.onOpenEvent});

  @override
  State<NextServiceCard> createState() => _NextServiceCardState();
}

class _NextServiceCardState extends State<NextServiceCard> {
  static const _carouselInterval = Duration(seconds: 5);
  final PageController _pageController = PageController();
  List<ScheduleEvent> _events = [];
  int _currentIndex = 0;
  bool _loading = true;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await ContentService.listScheduleEvents();
      if (!mounted) return;
      _setUpcomingEvents(events);
    } catch (_) {
      if (!mounted) return;
      _setUpcomingEvents(DataService.scheduleEvents);
    }
  }

  void _setUpcomingEvents(List<ScheduleEvent> events) {
    final upcomingEvents = _findNextDayEvents(events);
    setState(() {
      _events = upcomingEvents;
      _currentIndex = 0;
      _loading = false;
    });
    _carouselTimer?.cancel();
    if (upcomingEvents.length > 1) {
      _carouselTimer = Timer.periodic(_carouselInterval, (_) {
        if (!mounted || !_pageController.hasClients) return;
        final nextIndex = (_currentIndex + 1) % _events.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  List<ScheduleEvent> _findNextDayEvents(List<ScheduleEvent> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMinutes = now.hour * 60 + now.minute;

    for (var offset = 0; offset <= 366; offset++) {
      final date = today.add(Duration(days: offset));
      final eventsOnDay =
          events
              .where((event) {
                if (event.eventDate != null) {
                  return _sameDay(event.eventDate!, date);
                }
                if (event.monthlyTheme) {
                  if (date.weekday != DateTime.sunday) return false;
                  final ordinal = int.tryParse(
                    event.recurringCycle?.substring(0, 1) ?? '',
                  );
                  return ordinal == null ||
                      ((date.day - 1) ~/ 7) + 1 == ordinal;
                }
                return event.matchesDay(date.weekday);
              })
              .where((event) {
                return offset > 0 || _eventMinutes(event) >= currentMinutes;
              })
              .toList()
            ..sort(ScheduleEvent.compareByTime);

      if (eventsOnDay.isNotEmpty) return eventsOnDay;
    }
    return [];
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  int _eventMinutes(ScheduleEvent event) {
    final parts = event.time.split(':');
    final hours = int.tryParse(parts.first) ?? 0;
    final minutes = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hours * 60 + minutes;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 112,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_events.isEmpty) {
      return const Text('Nenhum evento futuro cadastrado na agenda.');
    }

    final nextEvent = _events[_currentIndex];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2540), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2540).withAlpha(60),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withAlpha(50),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withAlpha(120),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFFF59E0B),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'PRÓXIMO ENCONTRO • ${nextEvent.time}',
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_events.length > 1)
                  Text(
                    '${_currentIndex + 1}/${_events.length}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 130,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _events.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withAlpha(220),
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFF59E0B),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${event.location} • Sobral',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(200),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_events.length > 1) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _events.length,
                  (index) => Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentIndex
                          ? const Color(0xFFF59E0B)
                          : Colors.white.withAlpha(100),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onOpenEvent(nextEvent),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: const Text('Ver detalhes deste evento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
