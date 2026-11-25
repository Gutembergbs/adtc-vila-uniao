const _termosBloqueados = <String>{
  'arrombado',
  'bosta',
  'buceta',
  'cacete',
  'caralho',
  'cu',
  'fdp',
  'foda',
  'fodase',
  'merda',
  'porra',
  'puta',
  'puto',
  'viado',
};

class ConteudoInadequadoException implements Exception {
  const ConteudoInadequadoException();

  @override
  String toString() =>
      'O texto contém linguagem inadequada. Revise o pedido antes de publicar.';
}

bool contemTermoInadequado(String texto) {
  var normalizado = texto.toLowerCase();
  const acentos = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
  };
  for (final entry in acentos.entries) {
    normalizado = normalizado.replaceAll(entry.key, entry.value);
  }
  final palavras = normalizado
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'));
  return palavras.any(_termosBloqueados.contains);
}
