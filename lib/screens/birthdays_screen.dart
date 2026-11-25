import 'package:flutter/material.dart';

import '../models/monthly_birthday.dart';
import '../services/auth_service.dart';
import '../services/content_service.dart';
import '../theme/app_theme.dart';

class BirthdaysScreen extends StatefulWidget {
  final AuthService authService;

  const BirthdaysScreen({super.key, required this.authService});

  @override
  State<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends State<BirthdaysScreen> {
  final Map<int, List<MonthlyBirthday>> _birthdaysByMonth = {};
  final Map<int, Object> _errorsByMonth = {};
  final Set<int> _loadingMonths = {};
  final Map<int, int> _monthRequests = {};
  late final PageController _monthPageController;
  int _selectedMonth = DateTime.now().month;
  int _requestSequence = 0;
  String? _activeUserId;

  @override
  void initState() {
    super.initState();
    _monthPageController = PageController(initialPage: _selectedMonth - 1);
    widget.authService.addListener(_handleAuthChanged);
    _handleAuthChanged();
  }

  @override
  void dispose() {
    widget.authService.removeListener(_handleAuthChanged);
    _monthPageController.dispose();
    super.dispose();
  }

  void _handleAuthChanged() {
    final user = widget.authService.currentUser;
    if (!widget.authService.isAuthenticated || user == null || !user.isAdmin) {
      if (_activeUserId != null ||
          _birthdaysByMonth.isNotEmpty ||
          _loadingMonths.isNotEmpty) {
        setState(() {
          _activeUserId = null;
          _birthdaysByMonth.clear();
          _errorsByMonth.clear();
          _loadingMonths.clear();
          _monthRequests.clear();
          _requestSequence++;
        });
      }
      return;
    }

    if (_activeUserId != user.id) {
      setState(() {
        _activeUserId = user.id;
        _birthdaysByMonth.clear();
        _errorsByMonth.clear();
        _loadingMonths.clear();
        _monthRequests.clear();
        _requestSequence++;
      });
    }
    _loadBirthdays(_selectedMonth);
  }

  Future<void> _loadBirthdays(int month, {bool force = false}) async {
    final user = widget.authService.currentUser;
    if (!widget.authService.isAuthenticated || user == null || !user.isAdmin) {
      return;
    }
    if (!force &&
        (_birthdaysByMonth.containsKey(month) ||
            _loadingMonths.contains(month))) {
      return;
    }

    final request = ++_requestSequence;
    setState(() {
      _monthRequests[month] = request;
      _loadingMonths.add(month);
      _errorsByMonth.remove(month);
    });

    try {
      final birthdays = await ContentService.listMonthlyBirthdays(month: month);
      if (!mounted ||
          _monthRequests[month] != request ||
          widget.authService.currentUser?.id != user.id) {
        return;
      }
      setState(() {
        _birthdaysByMonth[month] = birthdays;
        _loadingMonths.remove(month);
        _monthRequests.remove(month);
      });
    } catch (error) {
      if (!mounted ||
          _monthRequests[month] != request ||
          widget.authService.currentUser?.id != user.id) {
        return;
      }
      setState(() {
        _errorsByMonth[month] = error;
        _loadingMonths.remove(month);
        _monthRequests.remove(month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aniversariantes')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07516B), Color(0xFF3295AD)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: PageView.builder(
          controller: _monthPageController,
          itemCount: 12,
          onPageChanged: (index) {
            setState(() => _selectedMonth = index + 1);
            _loadBirthdays(index + 1);
          },
          itemBuilder: (context, index) {
            final month = index + 1;
            return _buildMonthPage(month);
          },
        ),
      ),
    );
  }

  Widget _buildMonthPage(int month) {
    final birthdays = _birthdaysByMonth[month] ?? const <MonthlyBirthday>[];
    final error = _errorsByMonth[month];
    final isAdministrator = widget.authService.currentUser?.isAdmin == true;

    return RefreshIndicator(
      onRefresh: () => _loadBirthdays(month, force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          const Icon(Icons.cake_rounded, color: AppTheme.warmAmber, size: 34),
          const SizedBox(height: 8),
          Text(
            'ANIVERSARIANTES DE ${_monthLabel(month).toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Celebrando a vida da nossa família ADTC Vila União',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Deslize para os lados para ver outros meses',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (!isAdministrator)
            _buildMessage(
              icon: Icons.lock_outline_rounded,
              message:
                  'A consulta de aniversariantes é restrita à administração.',
            )
          else if (_loadingMonths.contains(month))
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            _buildError(month, error)
          else if (birthdays.isEmpty)
            _buildMessage(
              icon: Icons.event_busy_rounded,
              message: 'Nenhum aniversariante encontrado neste mês.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1000
                    ? 7
                    : width >= 760
                    ? 6
                    : width >= 540
                    ? 5
                    : width >= 340
                    ? 4
                    : 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: birthdays.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 7,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) =>
                      _buildBirthdayTile(birthdays[index], month),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBirthdayTile(MonthlyBirthday birthday, int month) {
    final initials = birthday.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final date =
        '${birthday.day.toString().padLeft(2, '0')}/'
        '${month.toString().padLeft(2, '0')}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: AppTheme.warmAmber, width: 1.5),
          ),
          child: ClipOval(
            child: birthday.photoUrl == null
                ? _buildBirthdayInitials(initials)
                : Image.network(
                    birthday.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildBirthdayInitials(initials),
                  ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '$date - ${birthday.name.toUpperCase()}',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.primaryNavy,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBirthdayInitials(String initials) => ColoredBox(
    color: const Color(0xFFE0F2FE),
    child: Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFF075985),
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    ),
  );

  Widget _buildError(int month, Object error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Não foi possível carregar os aniversariantes: '
              '$error',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _loadBirthdays(month, force: true),
                child: const Text('Tentar novamente'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage({required IconData icon, required String message}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.accentGold, size: 34),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _monthLabel(int month) {
    const months = [
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
    return months[month - 1];
  }
}
