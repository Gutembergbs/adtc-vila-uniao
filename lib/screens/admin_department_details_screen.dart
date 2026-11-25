import 'package:flutter/material.dart';

import '../models/department.dart';

class AdminDepartmentDetailsScreen extends StatefulWidget {
  final Department department;
  final Future<void> Function(Department department) onEditOptions;
  final Future<bool> Function(Department department) onDelete;

  const AdminDepartmentDetailsScreen({
    super.key,
    required this.department,
    required this.onEditOptions,
    required this.onDelete,
  });

  @override
  State<AdminDepartmentDetailsScreen> createState() =>
      _AdminDepartmentDetailsScreenState();
}

class _AdminDepartmentDetailsScreenState
    extends State<AdminDepartmentDetailsScreen> {
  late Department _department;

  @override
  void initState() {
    super.initState();
    _department = widget.department;
  }

  @override
  void didUpdateWidget(covariant AdminDepartmentDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.department != widget.department) {
      _department = widget.department;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_department.displayName),
      actions: [
        IconButton(
          tooltip: 'Editar departamento',
          onPressed: () => widget.onEditOptions(_department),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: _department.color,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white.withAlpha(40),
                      child: Icon(
                        _department.icon,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _department.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_department.conjuntoName?.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 4),
                      Text(
                        _department.conjuntoName!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _field('Nome do departamento', _department.name),
            _field('Nome do conjunto', _department.conjuntoName ?? ''),
            _field('Responsável', _department.leaderName),
            _field('Horário das reuniões', _department.meetingSchedule),
            _field('Descrição', _department.description, multiline: true),
            _field(
              'Atividades e responsabilidades',
              _department.responsibilities.join('\n'),
              multiline: true,
            ),
            _field('Tags', _department.tags.join(', ')),
            _field('Instagram', _department.instagram ?? ''),
            _field(
              'Histórico do conjunto',
              _department.conjuntoHistory ?? '',
              multiline: true,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _deleteDepartment,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir departamento'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(String label, String value, {bool multiline = false}) => Card(
    child: ListTile(
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(value.trim().isEmpty ? 'Não informado' : value),
      isThreeLine: multiline,
    ),
  );

  Future<void> _deleteDepartment() async {
    final deleted = await widget.onDelete(_department);
    if (deleted && mounted) Navigator.of(context).pop();
  }
}
