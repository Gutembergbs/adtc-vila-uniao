import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_navigation_actions.dart';

class AboutScreen extends StatelessWidget {
  final AuthService authService;

  const AboutScreen({super.key, required this.authService});

  Future<void> _openMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(DataService.churchMapsQuery)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openInstagram() async {
    final uri = Uri.parse(DataService.churchInstagramUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.https(
      'igreja-flutter.web.app',
      '/politica-privacidade.html',
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a política de privacidade.'),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir a política: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppNavigationMenuButton(
          showBackButton: true,
          onPressed: () => Navigator.of(context).maybePop(),
          user: authService.isAuthenticated ? authService.currentUser : null,
        ),
        title: const Text('Sobre a ADTC Vila União'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/church_logo.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ADTC Vila União',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    DataService.churchFullName,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Sobral - Ceará',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Nossa Identidade',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A ADTC Vila União é uma congregação ligada à Assembleia de Deus Templo Central em Sobral - CE. Somos uma igreja bíblica, pentecostal e acolhedora, comprometida com a pregação genuína do Evangelho de Cristo, o discipulado de vidas e a oração perseverante.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 20),

            // Slogan / Verse
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                DataService.churchVerse,
                style: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF1E3A8A),
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Localização & Contatos',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF0A2540),
                child: Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
              title: const Text(
                'Endereço',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(DataService.churchAddress),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: _openMaps,
              ),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF833AB4),
                child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
              title: const Text(
                'Instagram Oficial',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(DataService.churchInstagram),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: _openInstagram,
              ),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF334155),
                child: Icon(Icons.privacy_tip_outlined, color: Colors.white),
              ),
              title: const Text(
                'Política de Privacidade',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _openPrivacyPolicy(context),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                'ADTC Vila União App • v1.0.0\nDesenvolvido com carinho para a congregação de Sobral - CE',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
