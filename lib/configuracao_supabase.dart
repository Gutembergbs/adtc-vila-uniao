import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// URL do projeto, informada na execução sem gravar credenciais no código.
const String urlSupabase = String.fromEnvironment('SUPABASE_URL');

/// Chave pública (publishable/anon) do app; nunca use a chave `service_role`.
const String chavePublicaSupabase = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// Informa se a conexão foi inicializada e pode ser usada pelo serviço.
bool supabaseInicializado = false;
String? erroConfiguracaoSupabase;

/// Conecta ao Supabase quando as duas configurações foram fornecidas.
Future<void> inicializarSupabase() async {
  final configuracoesAusentes = <String>[
    if (urlSupabase.isEmpty) 'SUPABASE_URL',
    if (chavePublicaSupabase.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];
  if (configuracoesAusentes.isNotEmpty) {
    erroConfiguracaoSupabase =
        'Build sem ${configuracoesAusentes.join(' e ')}. Gere o app novamente com --dart-define.';
    return;
  }

  try {
    await Supabase.initialize(
      url: urlSupabase,
      publishableKey: chavePublicaSupabase,
    );
    supabaseInicializado = true;
    erroConfiguracaoSupabase = null;
  } catch (erro) {
    erroConfiguracaoSupabase =
        'Falha ao iniciar o Supabase. Confira a URL, a chave pública e a conexão com a internet.';
    debugPrint('Não foi possível inicializar o Supabase: $erro');
  }
}
