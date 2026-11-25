import 'package:flutter/material.dart';

import '../models/department.dart';
import '../models/department_assignment.dart';
import '../models/member_record.dart';
import '../services/content_service.dart';
import '../utils/member_date_utils.dart';

class AdminMemberDetailsScreen extends StatefulWidget {
  final MemberRecord member;
  final List<Department> departments;
  final List<DepartmentAssignment> assignments;
  final Future<void> Function() onAssignmentsChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function()? onConvertToVisitor;

  const AdminMemberDetailsScreen({
    super.key,
    required this.member,
    required this.departments,
    required this.assignments,
    required this.onAssignmentsChanged,
    required this.onEdit,
    required this.onDelete,
    this.onConvertToVisitor,
  });

  @override
  State<AdminMemberDetailsScreen> createState() =>
      _AdminMemberDetailsScreenState();
}

class _AdminMemberDetailsScreenState extends State<AdminMemberDetailsScreen> {
  late List<DepartmentAssignment> _assignments;

  MemberRecord get member => widget.member;

  @override
  void initState() {
    super.initState();
    _assignments = List.of(widget.assignments);
  }

  @override
  void didUpdateWidget(covariant AdminMemberDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assignments != widget.assignments) {
      _assignments = List.of(widget.assignments);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do membro'),
        actions: [
          IconButton(
            tooltip: 'Editar membro',
            onPressed: widget.onEdit,
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
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _MemberPhoto(path: member.photoPath, name: member.name),
                      const SizedBox(height: 16),
                      Text(
                        member.nickname.trim().isEmpty
                            ? member.name
                            : member.nickname,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        avatar: Icon(
                          member.isActive
                              ? Icons.check_circle_outline
                              : Icons.pause_circle_outline,
                        ),
                        label: Text(member.isActive ? 'Ativo' : 'Inativo'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildDepartmentAssignments(),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _detail('Nome completo', member.name),
                    _detail('Apelido', member.nickname),
                    _detail('Matrícula', member.membershipNumber ?? ''),
                    _detail('E-mail', member.email),
                    _detail('Telefone', member.phone),
                    _detail('Congregação', member.congregation),
                    _detail('Departamentos', member.department),
                    _detail(
                      'Data de batismo',
                      formatMemberDate(member.baptismDate),
                    ),
                    _detail(
                      'Data de nascimento',
                      formatMemberDate(member.birthDate),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar cadastro'),
              ),
              if (member.userId != null &&
                  widget.onConvertToVisitor != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.onConvertToVisitor,
                  icon: const Icon(Icons.person_pin_circle_outlined),
                  label: const Text('Transformar em visitante'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir cadastro'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB42318),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => ListTile(
    title: Text(label, style: const TextStyle(fontSize: 12)),
    subtitle: Text(value.trim().isEmpty ? 'Não informado' : value),
    dense: true,
  );

  Widget _buildDepartmentAssignments() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Departamentos e funções',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Atribuir departamento e função',
                onPressed: _addAssignment,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          if (_assignments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nenhum departamento ou função atribuída.'),
            )
          else
            ..._assignments.map((assignment) {
              final department = _departmentById(assignment.departmentId);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  department?.displayName ?? 'Departamento removido',
                  softWrap: true,
                ),
                subtitle: Text(assignment.role),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: 'Editar função',
                      onPressed: () => _editAssignment(assignment),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remover função',
                      onPressed: () => _deleteAssignment(assignment),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFB42318),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    ),
  );

  Department? _departmentById(String id) {
    for (final department in widget.departments) {
      if (department.id == id) return department;
    }
    return null;
  }

  Future<void> _addAssignment() async {
    if (widget.departments.isEmpty) {
      _showError('Cadastre um departamento antes de atribuir uma função.');
      return;
    }
    final memberId = member.id;
    if (memberId == null) {
      _showError('Salve o cadastro do membro antes de atribuí-lo.');
      return;
    }

    var selectedDepartmentId = widget.departments.first.id;
    var role = '';
    final assignment = await showDialog<DepartmentAssignment>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Atribuir departamento e função'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedDepartmentId,
                  menuMaxHeight: 320,
                  decoration: const InputDecoration(labelText: 'Departamento'),
                  items: widget.departments
                      .map(
                        (department) => DropdownMenuItem(
                          value: department.id,
                          child: Text(
                            department.displayName,
                            softWrap: true,
                            maxLines: 3,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      updateDialog(() => selectedDepartmentId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Função',
                    hintText: 'Ex.: Regente, professor, auxiliar',
                  ),
                  onChanged: (value) => role = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = role.trim();
                if (value.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  DepartmentAssignment(
                    id: '',
                    departmentId: selectedDepartmentId,
                    memberId: memberId,
                    role: value,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (assignment == null || !mounted) return;
    try {
      await ContentService.saveDepartmentAssignment(assignment);
      await _refreshAssignments();
    } catch (error) {
      _showError('Não foi possível atribuir a função: $error');
    }
  }

  Future<void> _editAssignment(DepartmentAssignment assignment) async {
    var role = assignment.role;
    final updatedRole = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar função'),
        content: TextFormField(
          initialValue: role,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Função no departamento',
          ),
          onChanged: (value) => role = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = role.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (updatedRole == null || !mounted) return;
    try {
      await ContentService.saveDepartmentAssignment(
        DepartmentAssignment(
          id: assignment.id,
          departmentId: assignment.departmentId,
          memberId: assignment.memberId,
          role: updatedRole,
        ),
      );
      await _refreshAssignments();
    } catch (error) {
      _showError('Não foi possível editar a função: $error');
    }
  }

  Future<void> _deleteAssignment(DepartmentAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover função?'),
        content: const Text(
          'O membro continuará cadastrado, mas esta função será removida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ContentService.deleteDepartmentAssignment(assignment.id);
      await _refreshAssignments();
    } catch (error) {
      _showError('Não foi possível remover a função: $error');
    }
  }

  Future<void> _refreshAssignments() async {
    final memberId = member.id;
    if (memberId == null) return;
    final assignments = await ContentService.listDepartmentAssignments();
    if (!mounted) return;
    setState(() {
      _assignments = assignments
          .where((assignment) => assignment.memberId == memberId)
          .toList();
    });
    await widget.onAssignmentsChanged();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Color(0xFFB42318)),
    );
  }
}

class _MemberPhoto extends StatelessWidget {
  final String? path;
  final String name;

  const _MemberPhoto({required this.path, required this.name});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: ContentService.createMemberPhotoUrl(path),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url != null && url.isNotEmpty) {
          return ClipOval(
            child: Image.network(
              url,
              width: 108,
              height: 108,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context),
            ),
          );
        }
        return _placeholder(context);
      },
    );
  }

  Widget _placeholder(BuildContext context) => CircleAvatar(
    radius: 54,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Text(
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
    ),
  );
}
