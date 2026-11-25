import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/department.dart';
import '../models/department_leader.dart';
import '../models/department_roster_member.dart';
import '../services/auth_service.dart';
import '../services/content_service.dart';

class DepartmentDetailScreen extends StatefulWidget {
  final Department department;
  final AuthService authService;

  const DepartmentDetailScreen({
    super.key,
    required this.department,
    required this.authService,
  });

  @override
  State<DepartmentDetailScreen> createState() => _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends State<DepartmentDetailScreen> {
  late Future<List<DepartmentRosterMember>> _departmentMembers;
  late Future<List<DepartmentLeader>> _departmentLeaders;

  Department get department => widget.department;

  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_handleAuthenticationChanged);
    _loadDepartmentMembers();
    _loadDepartmentLeaders();
  }

  @override
  void dispose() {
    widget.authService.removeListener(_handleAuthenticationChanged);
    super.dispose();
  }

  void _handleAuthenticationChanged() {
    if (!mounted) return;
    setState(_loadDepartmentLeaders);
  }

  void _loadDepartmentMembers() {
    if (widget.authService.currentUser?.isAdmin == true) {
      _departmentMembers = ContentService.listDepartmentRoster(
        department.id,
        department.name,
        department.displayName,
      );
    } else {
      _departmentMembers = Future.value(const []);
    }
  }

  void _loadDepartmentLeaders() {
    _departmentLeaders = ContentService.listDepartmentLeaders(
      department.id,
      department.leaderName,
    );
  }

  Future<void> _launchInstagram(BuildContext context) async {
    final instagram = department.instagram?.trim();
    if (instagram == null || instagram.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instagram ainda não cadastrado.')),
      );
      return;
    }

    final profile = instagram.startsWith('@')
        ? instagram.substring(1)
        : instagram;
    try {
      final normalizedProfile =
          profile.startsWith('http://') || profile.startsWith('https://')
          ? profile
          : profile.startsWith('instagram.com/') ||
                profile.startsWith('www.instagram.com/')
          ? 'https://$profile'
          : 'https://www.instagram.com/$profile';
      final uri = Uri.tryParse(normalizedProfile);
      if (uri == null ||
          !uri.hasAuthority ||
          ![
            'instagram.com',
            'www.instagram.com',
          ].contains(uri.host.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O link do Instagram é inválido.')),
        );
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o link do Instagram.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao abrir link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(department.conjuntoName ?? department.name),
        backgroundColor: department.color,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              decoration: BoxDecoration(
                color: department.color,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(department.icon, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  if (department.conjuntoName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        department.conjuntoName!,
                        style: TextStyle(
                          color: department.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    department.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ADTC Vila União • Sobral - CE',
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Cards Row
                  Row(
                    children: [
                      Expanded(child: _buildLeadershipCard(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          icon: Icons.schedule_rounded,
                          title: 'Encontros',
                          value: department.meetingSchedule,
                          accentColor: department.color,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Description
                  const Text(
                    'Sobre o grupo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    department.description,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Responsibilities / Activities
                  const Text(
                    'Atividades & Responsabilidades',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...department.responsibilities.map(
                    (resp) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: department.color.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: department.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              resp,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: department.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: department.color.withAlpha(20),
                        labelStyle: TextStyle(
                          color: department.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        side: BorderSide(color: department.color.withAlpha(60)),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // Call to action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchInstagram(context),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Abrir Instagram'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: department.color,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (department.conjuntoHistory?.trim().isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: department.color.withAlpha(12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: department.color.withAlpha(70),
                        ),
                      ),
                      child: Theme(
                        // Remove as linhas padrão superior e inferior do ExpansionTile
                        data: ThemeData(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          title: Text(
                            'Histórico do conjunto',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: department.color,
                            ),
                          ),
                          iconColor: department.color,
                          collapsedIconColor: department.color,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                department.conjuntoHistory!.trim(),
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (widget.authService.currentUser?.isAdmin == true) ...[
                    const SizedBox(height: 20),
                    _buildDepartmentMembers(),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentMembers() =>
      FutureBuilder<List<DepartmentRosterMember>>(
        future: _departmentMembers,
        builder: (context, snapshot) {
          final members = snapshot.data;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: department.color.withAlpha(12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: department.color.withAlpha(70)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membros do departamento',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: department.color,
                  ),
                ),
                const SizedBox(height: 10),
                if (snapshot.hasError)
                  const Text(
                    'Não foi possível carregar os membros do departamento.',
                  )
                else if (snapshot.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else if (members == null || members.isEmpty)
                  Text(
                    'Ainda não há membros cadastrados neste departamento.',
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                else
                  ...members.map(_buildDepartmentMember),
              ],
            ),
          );
        },
      );

  Widget _buildDepartmentMember(DepartmentRosterMember member) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(Icons.person_outline_rounded, color: department.color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(member.name)),
        if (member.role.isNotEmpty)
          Flexible(
            child: Text(
              member.role,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: department.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _buildLeadershipCard(
    BuildContext context,
  ) => FutureBuilder<List<DepartmentLeader>>(
    future: _departmentLeaders,
    builder: (context, snapshot) {
      final leaders = snapshot.data ?? [];
      final leaderNames = leaders.map((leader) => leader.name).join(', ');
      final profile = widget.authService.currentUser;
      final canContact =
          (profile?.hasApprovedMemberAccess == true ||
              profile?.isAdmin == true) &&
          leaders.any((leader) => leader.email?.trim().isNotEmpty == true);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCard(
            context,
            icon: Icons.person_rounded,
            title: 'Liderança',
            value: leaderNames.isEmpty ? department.leaderName : leaderNames,
            accentColor: department.color,
            onTap: canContact ? () => _showLeaderContactOptions(leaders) : null,
          ),
          if (snapshot.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Text(
                'Não foi possível atualizar a lista de líderes.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 11),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _showLeaderContactOptions(List<DepartmentLeader> leaders) async {
    final contactableLeaders = leaders
        .where((leader) => leader.email?.trim().isNotEmpty == true)
        .toList();
    if (contactableLeaders.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Liderança do departamento'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: contactableLeaders
                  .map(
                    (leader) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(leader.name),
                      subtitle: Text(leader.email!),
                      trailing: const Icon(Icons.email_outlined),
                      onTap: () => _sendLeaderEmail(leader),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendLeaderEmail(DepartmentLeader leader) async {
    final email = leader.email?.trim();
    if (email == null || email.isEmpty) return;

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Contato sobre ${department.displayName}'},
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o e-mail.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o e-mail: $error')),
      );
    }
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: accentColor,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
