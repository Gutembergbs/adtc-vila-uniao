import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/data_service.dart';

import '../services/auth_service.dart';
import '../widgets/app_navigation_actions.dart';

class MediaScreen extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onOpenDrawer;
  final VoidCallback onLoginRequired;

  const MediaScreen({
    super.key,
    required this.authService,
    required this.onOpenDrawer,
    required this.onLoginRequired,
  });

  Future<void> _openInstagram(BuildContext context) async {
    final uri = Uri.parse(DataService.churchInstagramUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abrindo perfil @adtcvilauniao no Instagram...'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  void _showProjectionSongs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: const [
                Icon(Icons.tv_rounded, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text(
                  'Projeção & Letras de Louvores',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Repertório do Ministério Livres pra Adorar projetado nos cultos:',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildSongItem(
              title: 'Porque Ele Vive',
              artist: 'Harpa Cristã / Tradicional',
              keyWord: 'Deus enviou seu Filho amado...',
            ),
            _buildSongItem(
              title: 'Bondade de Deus',
              artist: 'Ministério Livres pra Adorar',
              keyWord: 'Te amo, Deus, tua graça nunca falha...',
            ),
            _buildSongItem(
              title: 'Grandes Coisas Fez o Senhor',
              artist: 'Celebração Congregacional',
              keyWord: 'Grandes coisas fez o Senhor por nós...',
            ),
            _buildSongItem(
              title: 'Caminho no Deserto',
              artist: 'Adoração Congregacional',
              keyWord: 'Estás aqui operando milagres...',
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSongItem({
    required String title,
    required String artist,
    required String keyWord,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            artist,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
          ),
          const SizedBox(height: 6),
          Text(
            '“$keyWord”',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppNavigationMenuButton(
          onPressed: onOpenDrawer,
          showBackButton: true,
          user: authService.isAuthenticated ? authService.currentUser : null,
        ),
        title: const Text('Mídia & Comunicação'),
        actions: [
          AppNotificationsAction(
            authService: authService,
            onLoginRequired: onLoginRequired,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instagram Highlight Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF833AB4),
                    Color(0xFFFD1D1D),
                    Color(0xFFFCB045),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFD1D1D).withAlpha(50),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'OFICIAL',
                          style: TextStyle(
                            color: Color(0xFF833AB4),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Instagram Oficial',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '@adtcvilauniao',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fotos dos cultos, avisos diários, reels dos jovens Celebra, círculos de oração e transmissões ao vivo da congregação em Sobral.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openInstagram(context),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Abrir Instagram da Igreja'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF833AB4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Serviços da Equipe de Mídia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            // Feature 1: Gravações & Transmissão
            _buildMediaFeatureTile(
              icon: Icons.videocam_rounded,
              color: const Color(0xFFEF4444),
              title: 'Gravação & Transmissão dos Cultos',
              description:
                  'Cultos gravados em alta definição nos domingos às 18h e quintas de doutrina. Assista novamente as mensagens ministradas em Sobral.',
            ),

            const SizedBox(height: 12),

            // Feature 2: Postagens e Redes Sociais
            _buildMediaFeatureTile(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'Postagens & Comunicação Digital',
              description:
                  'Criação de artes, stories e cobertura fotográfica em tempo real dos congressos de senhoras (Filadélfia), jovens (Celebra) e EBD.',
            ),

            const SizedBox(height: 12),

            // Feature 3: Projeção da Igreja
            _buildMediaFeatureTile(
              icon: Icons.tv_rounded,
              color: const Color(0xFF0284C7),
              title: 'Projeção do Telão no Templo',
              description:
                  'Sincronização imediata das letras dos hinos e versículos durante a ministração da Palavra de Deus.',
              trailingButtonText: 'Ver Repertório',
              onTrailingPressed: () => _showProjectionSongs(context),
            ),

            const SizedBox(height: 20),

            // Contact the media team
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.mic_external_on_rounded,
                    color: Color(0xFF0A2540),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Quer servir na equipe de Mídia (câmera, slides ou redes)? Procure os líderes após o culto.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildImageUseNotice(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUseNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2540),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8C77A), width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: Color(0xFFD8C77A),
            size: 44,
          ),
          const SizedBox(height: 10),
          const Text(
            'AUTORIZAÇÃO DE USO DE IMAGEM',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD8C77A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Prezados membros, congregados e visitantes: durante os cultos e '
            'eventos realizados em nossa igreja, poderão ser captadas imagens '
            'e vídeos para documentar e divulgar as atividades da ADTC Vila '
            'União, em conformidade com a Lei Geral de Proteção de Dados '
            '(LGPD) — Lei nº 13.709/2018.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFF3E8B0),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Para dúvidas ou solicitações sobre o uso de imagem, procure a '
            'Equipe de Mídia da ADTC Vila União.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Equipe de Mídia — ADTC Vila União',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD8C77A),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaFeatureTile({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    String? trailingButtonText,
    VoidCallback? onTrailingPressed,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
            if (trailingButtonText != null && onTrailingPressed != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onTrailingPressed,
                icon: const Icon(Icons.lyrics_rounded, size: 16),
                label: Text(trailingButtonText),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
