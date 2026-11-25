import 'package:flutter/material.dart';

import '../models/department.dart';
import '../models/department_roster_member.dart';
import '../services/content_service.dart';

class DepartmentMemberMapScreen extends StatefulWidget {
  final Department department;

  const DepartmentMemberMapScreen({super.key, required this.department});

  @override
  State<DepartmentMemberMapScreen> createState() =>
      _DepartmentMemberMapScreenState();
}

class _DepartmentMemberMapScreenState extends State<DepartmentMemberMapScreen> {
  late final Future<List<DepartmentRosterMember>> _members;

  @override
  void initState() {
    super.initState();
    _members = ContentService.listDepartmentRoster(
      widget.department.id,
      widget.department.name,
      widget.department.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final department = widget.department;
    return Scaffold(
      appBar: AppBar(title: Text(department.displayName)),
      body: FutureBuilder<List<DepartmentRosterMember>>(
        future: _members,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar os membros: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final grouped = <String, List<DepartmentRosterMember>>{};
          for (final member in snapshot.data!) {
            final roles = member.roles;
            if (roles.isEmpty) roles.add('Sem função atribuída');
            for (final role in roles) {
              grouped.putIfAbsent(role, () => []).add(member);
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              _DepartmentNode(department: department),
              if (grouped.isNotEmpty)
                Center(
                  child: Container(
                    width: 2,
                    height: 28,
                    color: department.color.withAlpha(100),
                  ),
                ),
              if (grouped.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Ainda não há membros ativos vinculados a este departamento.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ...grouped.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _RoleBranch(
                    department: department,
                    role: entry.key,
                    members: entry.value,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DepartmentNode extends StatelessWidget {
  final Department department;

  const _DepartmentNode({required this.department});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Card(
        color: department.color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withAlpha(40),
                child: Icon(department.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  department.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RoleBranch extends StatelessWidget {
  final Department department;
  final String role;
  final List<DepartmentRosterMember> members;

  const _RoleBranch({
    required this.department,
    required this.role,
    required this.members,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_tree_rounded, color: department.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      role,
                      style: TextStyle(
                        color: department.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text('${members.length}'),
                ],
              ),
              const Divider(),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: members
                    .map(
                      (member) => _MemberNode(
                        member: member,
                        department: department,
                        role: role,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MemberNode extends StatelessWidget {
  final DepartmentRosterMember member;
  final Department department;
  final String role;

  const _MemberNode({
    required this.member,
    required this.department,
    required this.role,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _photo(member, 42),
                const SizedBox(height: 12),
                Text(
                  member.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: department.color),
                ),
                const SizedBox(height: 12),
                Text(department.displayName, textAlign: TextAlign.center),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _photo(member, 30),
            const SizedBox(height: 6),
            Text(
              member.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _photo(DepartmentRosterMember person, double radius) {
    final url = person.photoUrl;
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: department.color.withAlpha(35),
        child: Icon(Icons.person_rounded, color: department.color),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: department.color.withAlpha(35),
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, _) {},
      child: Text(
        person.name.trim().isEmpty ? '?' : person.name.trim()[0].toUpperCase(),
      ),
    );
  }
}
