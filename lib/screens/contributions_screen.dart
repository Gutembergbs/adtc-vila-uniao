import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';

class ContributionsScreen extends StatefulWidget {
  final AuthService authService;

  const ContributionsScreen({super.key, required this.authService});

  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> {
  static const _destinacoes = ['Dízimo', 'Oferta', 'Missões', 'Manutenção'];
  String _destinacao = _destinacoes.first;
  bool _copiada = false;

  /// Copia a chave PIX configurada pelo app e confirma visualmente.
  Future<void> _copiarChave() async {
    await Clipboard.setData(
      const ClipboardData(text: DataService.churchPixKey),
    );
    if (!mounted) return;
    setState(() => _copiada = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Chave PIX copiada.')));
  }

  /// Abre a folha nativa de compartilhamento com a finalidade selecionada.
  Future<void> _compartilharDados() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Contribuição para ${DataService.churchName}\n'
            'Finalidade: $_destinacao\n'
            'Chave PIX: ${DataService.churchPixKey}\n'
            'Confira o favorecido no seu banco antes de confirmar.',
      ),
    );
  }

  Future<void> _enviarComprovanteWhatsApp() async {
    final message = Uri.encodeComponent(
      'Olá! Estou enviando o comprovante da minha contribuição para '
      '${DataService.churchName}.\nFinalidade: $_destinacao.',
    );
    final uri = Uri.parse(
      'https://wa.me/${DataService.contributionsWhatsAppPhone}?text=$message',
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o WhatsApp: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contribuições')),
      body: AnimatedBuilder(
        animation: widget.authService,
        builder: (context, _) {
          if (!widget.authService.hasApprovedMemberAccess) {
            return _buildRestrictedAccess(context);
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              final introduction = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIntroductionCard(),
                  const SizedBox(height: 16),
                  _buildDestinationSelector(),
                ],
              );
              final pixCard = _buildPixCard();
              final content = wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: introduction),
                        const SizedBox(width: 24),
                        Expanded(flex: 7, child: pixCard),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        introduction,
                        const SizedBox(height: 16),
                        pixCard,
                      ],
                    );

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: ListView(
                    padding: EdgeInsets.all(wide ? 28 : 16),
                    children: [
                      content,
                      const SizedBox(height: 12),
                      const Text(
                        'O aplicativo não processa pagamentos nem confirma depósitos. Para enviar comprovantes, entre em contato diretamente com a tesouraria.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRestrictedAccess(BuildContext context) {
    final isPending = widget.authService.isAwaitingApproval;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPending
                        ? Icons.hourglass_top_rounded
                        : Icons.lock_outline_rounded,
                    color: const Color(0xFF0F766E),
                    size: 46,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPending ? 'Aguardando aprovação' : 'Acesso restrito',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isPending
                        ? 'A área de contribuições estará disponível após a aprovação da administração.'
                        : 'A área de contribuições está disponível somente para membros com acesso autorizado.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroductionCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryNavy, AppTheme.primaryBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.volunteer_activism_rounded,
                  color: AppTheme.warmAmber,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dízimos, ofertas e missões',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${DataService.churchFullName}\n${DataService.churchCity}',
              style: const TextStyle(color: Color(0xFFE2E8F0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _destinacao,
      decoration: const InputDecoration(
        labelText: 'Finalidade da contribuição',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: _destinacoes
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _destinacao = value);
      },
    );
  }

  Widget _buildPixCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PIX oficial',
              style: TextStyle(
                color: AppTheme.primaryNavy,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Confirme o nome do favorecido exibido pelo seu banco antes de concluir qualquer transferência.',
              style: TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final qrSize = constraints.maxWidth.clamp(0.0, 260.0);
                return Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/pix_contribuicao_qr.png',
                      width: qrSize,
                      height: qrSize,
                      fit: BoxFit.contain,
                      semanticLabel: 'QR Code Pix para contribuição',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Escaneie o QR Code com o app do seu banco.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF475569)),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded, color: AppTheme.primaryNavy),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: SelectableText(
                      DataService.churchPixKey,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: _copiada ? 'Chave copiada' : 'Copiar chave PIX',
                    onPressed: _copiarChave,
                    icon: Icon(
                      _copiada ? Icons.check_rounded : Icons.copy_rounded,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _compartilharDados,
                icon: const Icon(
                  Icons.share_outlined,
                  color: AppTheme.primaryNavy,
                ),
                label: const Text('Compartilhar dados PIX'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  side: const BorderSide(color: AppTheme.primaryNavy),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _enviarComprovanteWhatsApp,
                icon: const Icon(
                  Icons.chat_rounded,
                  color: AppTheme.primaryNavy,
                ),
                label: const Text('Enviar comprovante pelo WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.warmAmber,
                  foregroundColor: AppTheme.primaryNavy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
