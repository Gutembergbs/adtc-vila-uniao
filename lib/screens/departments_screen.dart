import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/content_service.dart';
import '../models/department.dart';
import '../widgets/department_card.dart';
import '../widgets/app_navigation_actions.dart';
import 'department_detail_screen.dart';

class DepartmentsScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onOpenDrawer;
  final VoidCallback onLoginRequired;
  final bool isVisible;
  final int refreshToken;

  const DepartmentsScreen({
    super.key,
    required this.authService,
    required this.onOpenDrawer,
    required this.onLoginRequired,
    this.isVisible = true,
    this.refreshToken = 0,
  });

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  List<Department> _departments = [];
  bool _loading = true;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void didUpdateWidget(covariant DepartmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.isVisible && widget.isVisible) ||
        oldWidget.refreshToken != widget.refreshToken) {
      _loadDepartments();
    }
  }

  /// Busca os departamentos publicados e mantém a vitrine local se houver falha.
  Future<void> _loadDepartments() async {
    try {
      final departments = await ContentService.listDepartments();
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _departments = DataService.departments;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar os membros.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDepartments = _departments.where((dept) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          dept.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (dept.conjuntoName != null &&
              dept.conjuntoName!.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              )) ||
          dept.description.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedCategory == null) return true;
      if (_selectedCategory == 'conjuntos') return dept.conjuntoName != null;
      if (_selectedCategory == 'servico') {
        return dept.id == 'midia' ||
            dept.id == 'obreiros' ||
            dept.id == 'denoc';
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: AppNavigationMenuButton(
          onPressed: widget.onOpenDrawer,
          showBackButton: true,
          user: widget.authService.isAuthenticated
              ? widget.authService.currentUser
              : null,
        ),
        title: const Text('Membros & Conjuntos'),
        actions: [
          AppNotificationsAction(
            authService: widget.authService,
            onLoginRequired: widget.onLoginRequired,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF0A2540),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar membro ou conjunto...',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(160)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    fillColor: Colors.white.withAlpha(25),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'Todos (${_departments.length})',
                        isSelected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Com Conjuntos',
                        isSelected: _selectedCategory == 'conjuntos',
                        onTap: () =>
                            setState(() => _selectedCategory = 'conjuntos'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Serviço & Estrutura',
                        isSelected: _selectedCategory == 'servico',
                        onTap: () =>
                            setState(() => _selectedCategory = 'servico'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredDepartments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 50,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhum membro ou conjunto encontrado.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDepartments.length,
                    itemBuilder: (context, index) {
                      final dept = filteredDepartments[index];
                      return DepartmentCard(
                        department: dept,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DepartmentDetailScreen(
                                department: dept,
                                authService: widget.authService,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD97706)
              : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD97706)
                : Colors.white.withAlpha(60),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
