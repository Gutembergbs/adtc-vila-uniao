bool isEmailConfirmationCallback(Uri uri) {
  Map<String, String> fragmentParameters;
  try {
    fragmentParameters = Uri.splitQueryString(uri.fragment);
  } on FormatException {
    fragmentParameters = const {};
  }
  final authType = uri.queryParameters['type'] ?? fragmentParameters['type'];
  return authType == 'signup' || authType == 'email';
}
