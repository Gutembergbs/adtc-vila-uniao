# ADTC Vila União

Aplicativo Flutter da congregação ADTC Vila União, em Sobral (CE).

Código-fonte: <https://github.com/Gutembergbs/adtc-vila-uniao>  
Versão Web: <https://igreja-flutter.web.app>

## Recursos

- Portal de membros e visitantes.
- Agenda, inscrições e lembretes.
- Pedidos de oração e moderação administrativa.
- Comunicados e notificações push.
- Departamentos, escalas, Bíblia e Harpa Cristã.

## Requisitos

- Flutter estável.
- Arquivos locais `supabase.json` e `firebase.json`, não enviados ao Git.
- Acesso aos projetos Supabase e Firebase para publicação.

## Executar e validar

```powershell
flutter pub get
flutter run
```

Para validar as alterações:

```powershell
flutter analyze
flutter test
```

## Publicar a Web

Configure `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` em `supabase.json`.
Configure o Firebase Web em `firebase.json`. Esses arquivos são locais e
ignorados pelo Git.

```powershell
$config = Get-Content -Raw supabase.json | ConvertFrom-Json
if (-not $config.SUPABASE_URL -or -not $config.SUPABASE_PUBLISHABLE_KEY) {
  throw "Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY em supabase.json."
}
flutter build web --release `
  "--dart-define=SUPABASE_URL=$($config.SUPABASE_URL)" `
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($config.SUPABASE_PUBLISHABLE_KEY)" `
  --dart-define-from-file=firebase.json
if ($LASTEXITCODE -ne 0) { throw "A compilação Web falhou." }
firebase --config firebase.hosting.json deploy --only hosting --project igreja-flutter
```

Para publicar uma versão de teste antes da produção:

```powershell
firebase --config firebase.hosting.json hosting:channel:deploy preview --project igreja-flutter
```

## Supabase

Mantenha os arquivos em `supabase/migrations`: eles documentam a evolução do
banco. Não os apague nem os renomeie para limpar o histórico. O banco de
produção já contém alterações cujo histórico do CLI precisa ser reconciliado;
faça backup e confira esse histórico antes de executar `supabase db push` ou
aplicar novamente migrations.

As notificações da agenda e os lembretes Web dependem de Edge Functions e de
configuração no Supabase. Consulte
[o guia de notificações da agenda](supabase/functions/notificar-agenda/README.md)
antes de alterar ou republicar essas funções.

## Privacidade e lojas

- Política: <https://igreja-flutter.web.app/politica-privacidade.html>
- Solicitação de exclusão de conta:
  <https://igreja-flutter.web.app/exclusao-de-conta.html>
- Para publicar na Google Play, gere um App Bundle de release e mantenha a
  chave de assinatura fora do repositório.

