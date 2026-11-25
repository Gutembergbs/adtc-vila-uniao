# Notificações da agenda

A função envia FCM ao tópico `agenda` para dispositivos nativos e envia
diretamente para tokens Web registrados quando um administrador solicita o
envio no app. A opção “Somente o evento” envia o nome do evento sem classificá-
lo como novo, alterado ou cancelado. Salvar, editar ou excluir um evento não
dispara uma notificação automática. A função confere manualmente o JWT Supabase
e o usuário na tabela `administradores` antes do envio; ela não usa nem expõe a
chave `service_role` no aplicativo. A configuração `verify_jwt = false` evita
uma rejeição antecipada do JWT pelo gateway; a função exige e valida o token
por conta própria.

1. No Firebase Console, crie um projeto e adicione um app Android com este
   application ID: `com.adtc.vilauniao.adtc_vila_uniao`. Ative Firebase Cloud
   Messaging no projeto.
2. Em Configurações do projeto > Geral, copie a chave de API do app, o ID do
   app Android, o ID do remetente (sender ID) e o ID do projeto. Na raiz do
   projeto Flutter, copie `firebase.example.json` para `firebase.json` e
   preencha esses quatro valores. `firebase.json` está no `.gitignore` e
   contém somente opções públicas do cliente, não uma conta de serviço.
3. Salve o arquivo baixado do Firebase como
   `android/app/google-services.json`. Confira se o package name é
   `com.adtc.vilauniao.adtc_vila_uniao`. O Gradle usa esse arquivo para
   inicializar o Firebase nativo. Gere o APK usando os dois arquivos locais de
   configuração:

   ```powershell
   flutter build apk --release `
     --dart-define-from-file=supabase.json `
     --dart-define-from-file=firebase.json
   ```

   Instale esse APK no aparelho e abra o app pelo menos uma vez.
4. No Google Cloud Console, abra o projeto Firebase e crie uma nova chave
   privada de conta de serviço com permissão para enviar mensagens Firebase
   Cloud Messaging. O `project_id` dentro do JSON precisa ser o mesmo ID do
   projeto Firebase usado pelo app. Se qualquer chave privada foi incluída em
   ZIP, código do app ou compartilhada, revogue-a e gere outra. Não coloque
   esse JSON no app.
5. No Supabase Dashboard, em Edge Functions > Secrets, configure:
   - `FIREBASE_SERVICE_ACCOUNT`: todo o JSON da conta de serviço, preservado
     como um único valor JSON.
   - `FIREBASE_PROJECT_ID`: o mesmo project ID do Firebase usado pelo app.
6. Publique a função autenticada na raiz do projeto:

   ```powershell
   supabase functions deploy notificar-agenda
   ```

   Ela usa o token Bearer da sessão para confirmar o usuário e a permissão de
   administrador antes de enviar o aviso. Solicitações sem token, com token
   inválido ou de usuário não administrador são rejeitadas pela própria função.
7. Em Database > Webhooks, remova qualquer webhook antigo de
   `public.eventos_agenda` apontando para `notificar-agenda` e remova o segredo
   `AGENDA_WEBHOOK_SECRET` se ele ainda estiver configurado. Não crie um novo
   webhook: a função agora recebe somente solicitações manuais do app.
8. No app, abra Agenda, toque no sino e ative “Avisar sobre mudanças na agenda”.
   Na Web, o membro precisa estar autenticado e permitir as notificações do
   navegador; aplique também a migration
   `20261110050000_allow_web_device_tokens.sql`. Na tela de administração, use
   o botão “Notificar evento agora” no evento, escolha se é um evento novo,
   alterado, cancelado ou somente o evento e confirme o envio. Essa ação envia
   aos tokens Web registrados e ao tópico nativo `agenda`; as alterações em si
   continuam sendo atualizadas em tempo real sem avisos automáticos.

## Lembretes automáticos na Web

O navegador não consegue agendar uma notificação local confiável para quando o
site estiver fechado. Para isso, o servidor verifica a agenda a cada minuto e
envia push pelo Firebase aos navegadores que ativaram “Lembretes dos eventos”.
O lembrete usa a antecedência escolhida (10, 15, 30 ou 60 minutos), considera
todos os tipos de evento da agenda no fuso `America/Fortaleza` e só é enviado
uma vez por evento, ocorrência e antecedência. O navegador precisa ter permitido
notificações e ter sido registrado na conta pelo menos uma vez.

1. Aplique
   `supabase/migrations/20261115100000_web_agenda_reminders.sql` depois da
   migration `20261110050000_allow_web_device_tokens.sql`.
2. No Supabase Dashboard, habilite as extensões `pg_cron`, `pg_net` e Vault.
   Em Edge Functions > Secrets, configure `AGENDA_REMINDER_SECRET` com um
   segredo aleatório forte, além de `FIREBASE_SERVICE_ACCOUNT` e
   `FIREBASE_PROJECT_ID` já usados pela função manual.
3. Guarde no Vault, sem incluir os valores no repositório, a URL do projeto e
   o mesmo segredo da função:

   ```sql
   select vault.create_secret(
     'https://<project-ref>.supabase.co',
     'agenda_reminder_project_url'
   );
   select vault.create_secret(
     '<mesmo valor configurado em AGENDA_REMINDER_SECRET>',
     'agenda_reminder_secret'
   );
   ```

4. Publique a nova função:

   ```powershell
   supabase functions deploy notificar-lembretes-agenda
   ```

5. No SQL Editor, crie o job abaixo uma única vez:

   ```sql
   select cron.schedule(
     'notificar-lembretes-agenda',
     '* * * * *',
     $job$
       select net.http_post(
         url := (
           select decrypted_secret
           from vault.decrypted_secrets
           where name = 'agenda_reminder_project_url'
         ) || '/functions/v1/notificar-lembretes-agenda',
         headers := jsonb_build_object(
           'Content-Type', 'application/json',
           'x-agenda-reminder-secret', (
             select decrypted_secret
             from vault.decrypted_secrets
             where name = 'agenda_reminder_secret'
           )
         ),
         body := '{}'::jsonb
       );
     $job$
   );
   ```

   Confirme a criação em `cron.job` e verifique as execuções recentes em
   `cron.job_run_details`. Se precisar recriar o job, remova primeiro apenas
   esse job pelo nome `notificar-lembretes-agenda`.

Os lembretes push do servidor funcionam com o site fechado, desde que o
navegador e o sistema operacional permitam notificações em segundo plano.
Permissão negada, navegador sem suporte ou notificações do sistema desligadas
impedem a entrega. Isso é diferente de um alarme local no celular: o envio é
feito pelo servidor e depende do cron e da Edge Function estarem ativos.

O tópico `agenda` é opt-in por dispositivo nativo. Um aviso só chega depois que
a função foi publicada, o usuário permitiu notificações e o dispositivo se
inscreveu no tópico. Na Web, o token do navegador fica associado à conta de
membro em `device_tokens`; mensagens Web sem payload `notification` são
exibidas pelo service worker do Firebase em segundo plano. Mensagens nativas
com payload `notification` são exibidas pelo FCM. Android precisa ter aberto o
app ao menos uma vez e o usuário não pode ter feito “Forçar parada” nas
configurações; após forçar a parada, abra o app novamente para retomar a
entrega.

O tópico nativo `agenda` não depende da tabela de tokens. O envio Web consulta
`device_tokens`; aplique a migration que libera a plataforma `web` e adiciona
`agenda_enabled` antes de publicar a função atualizada. Não use a função legada
`sendPush` para esta configuração: ela usa o endpoint HTTP legado do FCM.
Nunca inclua a conta de serviço Firebase ou `service_role` no app,
em `firebase.json` ou nos comandos de build.

Para iOS, cadastre também o bundle ID `com.adtc.vilauniao.adtcVilaUniao`,
configure APNs no Firebase e adicione `FIREBASE_IOS_BUNDLE_ID` com esse valor
ao `firebase.json` antes de compilar para iOS.
