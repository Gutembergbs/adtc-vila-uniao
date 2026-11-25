const accountDeletionSupportEmail = 'gutembergbs.suporte@gmail.com';

Uri buildAccountDeletionRequestUri({
  required String name,
  required String email,
  required String userId,
}) {
  return Uri(
    scheme: 'mailto',
    path: accountDeletionSupportEmail,
    queryParameters: {
      'subject': 'Solicitação de exclusão de conta - ADTC Vila União',
      'body': '''
Solicito a exclusão da minha conta e dos dados pessoais associados ao app ADTC Vila União.

Nome: $name
E-mail da conta: $email
Identificador da conta: $userId

Se houver pedidos de oração publicados por mim que também devam ser removidos, informarei abaixo:
''',
    },
  );
}
