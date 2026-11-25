import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../configuracao_supabase.dart';
import '../models/department.dart';
import '../models/department_assignment.dart';
import '../models/department_leader.dart';
import '../models/department_roster_member.dart';
import '../models/announcement.dart';
import '../models/member_record.dart';
import '../models/member_notice.dart';
import '../models/member_schedule_assignment.dart';
import '../models/monthly_birthday.dart';
import '../models/scale_item.dart';
import '../models/schedule_event.dart';
import 'data_service.dart';

enum AgendaNotificationType { added, changed, cancelled, event }

/// Lê o conteúdo público e grava alterações administrativas no Supabase.
class ContentService {
  /// Lista departamentos; usa os exemplos locais quando o banco não foi ligado.
  /// Lista eventos semanais e temas mensais cadastrados no banco.
  static Future<List<ScheduleEvent>> listScheduleEvents() async {
    if (!supabaseInicializado) {
      return [
        ...DataService.scheduleEvents,
        ...DataService.monthlySundayThemes.map(
          (event) => event.copyWithMonthlyTheme(),
        ),
      ];
    }

    return _listScheduleEventsFromDatabase();
  }

  /// Lista eventos diretamente do banco, sem dados demonstrativos offline.
  static Future<List<ScheduleEvent>> listScheduleEventsFromDatabase() async {
    if (!supabaseInicializado) {
      throw StateError(
        'Configure o Supabase para carregar a programação do banco.',
      );
    }
    return _listScheduleEventsFromDatabase();
  }

  static Future<List<ScheduleEvent>> _listScheduleEventsFromDatabase() async {
    final rows = await Supabase.instance.client
        .from('eventos_agenda')
        .select()
        .order('dia_semana')
        .order('horario');
    return (rows as List)
        .map(
          (row) => ScheduleEvent.fromDatabase(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<List<Announcement>> listAnnouncementsForMember() async {
    final announcements = <Announcement>[];
    if (!supabaseInicializado) {
      return List<Announcement>.from(
        DataService.announcements.where((item) => item.isMembersOnly),
      );
    }
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Entre na sua conta para consultar seus avisos.');
    }
    final member = await client
        .from('membros')
        .select('id')
        .eq('usuario_id', userId)
        .eq('ativo', true)
        .maybeSingle();
    if (member == null) {
      throw StateError('Não foi encontrado um cadastro ativo para sua conta.');
    }
    final rows = await client
        .from('avisos_membros')
        .select()
        .eq('membro_id', member['id'])
        .order('criado_em', ascending: false);
    announcements.addAll(
      (rows as List).map(
        (row) => Announcement.fromMemberNoticeDatabase(
          Map<String, dynamic>.from(row),
        ),
      ),
    );
    return announcements;
  }

  static Future<List<Announcement>> listNotifications(String userId) async {
    _requireSupabase();
    final client = Supabase.instance.client;
    final recipients = await client
        .from('notificacoes_destinatarios')
        .select('notificacao_id,lida_em')
        .eq('usuario_id', userId)
        .order('criado_em', ascending: false);
    final recipientRows = (recipients as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final notificationIds = recipientRows
        .map((row) => row['notificacao_id'] as String)
        .toList();
    if (notificationIds.isEmpty) return [];

    final rows = await client
        .from('notificacoes')
        .select()
        .inFilter('id', notificationIds);
    final notificationsById = {
      for (final row in rows as List)
        row['id'] as String: Announcement.fromNotificationDatabase(
          Map<String, dynamic>.from(row),
        ),
    };
    return recipientRows
        .map((recipient) {
          final notification =
              notificationsById[recipient['notificacao_id'] as String];
          return notification?.copyWith(isRead: recipient['lida_em'] != null);
        })
        .whereType<Announcement>()
        .toList();
  }

  static Future<List<Announcement>> listUnreadNotifications(
    String userId,
  ) async {
    final notifications = await listNotifications(userId);
    return notifications.where((notification) => !notification.isRead).toList();
  }

  static Future<List<Announcement>> listAdminNotifications() async {
    _requireSupabase();
    final rows = await Supabase.instance.client
        .from('notificacoes')
        .select()
        .eq('tipo', 'personalizada')
        .order('criado_em', ascending: false);
    return (rows as List)
        .map(
          (row) => Announcement.fromNotificationDatabase(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  static Future<String> saveCustomNotification({
    String? id,
    required String title,
    required String summary,
    required String content,
    required String category,
  }) async {
    _requireSupabase();
    final trimmedTitle = title.trim();
    final trimmedContent = content.trim();
    if (trimmedTitle.isEmpty || trimmedContent.isEmpty) {
      throw ArgumentError('Informe o título e o conteúdo da notificação.');
    }

    final client = Supabase.instance.client;
    final values = {
      'tipo': 'personalizada',
      'titulo': trimmedTitle,
      'resumo': summary.trim(),
      'conteudo': trimmedContent,
      'categoria': category.trim().isEmpty ? 'Geral' : category.trim(),
    };
    if (id == null) {
      final row = await client
          .from('notificacoes')
          .insert({...values, 'criado_por': client.auth.currentUser?.id})
          .select('id')
          .single();
      return row['id'] as String;
    }
    await client.from('notificacoes').update(values).eq('id', id);
    return id;
  }

  static Future<void> deleteCustomNotification(String id) async {
    _requireSupabase();
    await Supabase.instance.client
        .from('notificacoes')
        .delete()
        .eq('id', id)
        .eq('tipo', 'personalizada');
  }

  static Future<void> markNotificationRead({
    required String userId,
    required String notificationId,
  }) async {
    _requireSupabase();
    await Supabase.instance.client
        .from('notificacoes_destinatarios')
        .update({'lida_em': DateTime.now().toUtc().toIso8601String()})
        .eq('usuario_id', userId)
        .eq('notificacao_id', notificationId)
        .isFilter('lida_em', null);
  }

  static Future<void> markAllNotificationsRead(String userId) async {
    _requireSupabase();
    await Supabase.instance.client
        .from('notificacoes_destinatarios')
        .update({'lida_em': DateTime.now().toUtc().toIso8601String()})
        .eq('usuario_id', userId)
        .isFilter('lida_em', null);
  }

  static Future<Map<String, dynamic>> sendCustomNotification(
    String notificationId,
  ) async {
    _requireSupabase();
    final response = await Supabase.instance.client.functions.invoke(
      'send-custom-notification',
      body: {'notificationId': notificationId},
    );
    if (response.data is Map && (response.data as Map)['sent'] == true) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw StateError(
      'O servidor não confirmou o envio da notificação: ${response.data}',
    );
  }

  static Future<List<MonthlyBirthday>> listMonthlyBirthdays({
    required int month,
  }) async {
    _requireSupabase();
    if (month < 1 || month > 12) {
      throw ArgumentError.value(
        month,
        'month',
        'O mês deve estar entre 1 e 12.',
      );
    }
    final rows = await Supabase.instance.client.rpc(
      'aniversariantes_do_mes',
      params: {'p_mes': month},
    );
    final storage = Supabase.instance.client.storage.from('fotos-membros');
    return Future.wait(
      (rows as List).map((value) async {
        final row = Map<String, dynamic>.from(value);
        final photoPath = row['foto_path'] as String?;
        final photoUrl = photoPath == null
            ? null
            : await storage.createSignedUrl(photoPath, 3600);
        return MonthlyBirthday.fromDatabase(row, photoUrl: photoUrl);
      }),
    );
  }

  static Future<String> saveMemberNotice({
    required String memberId,
    required String departmentId,
    required String title,
    required String content,
  }) async {
    _requireSupabase();
    final trimmedContent = content.trim();
    final row = await Supabase.instance.client
        .from('avisos_membros')
        .insert({
          'membro_id': memberId,
          'departamento_id': departmentId,
          'titulo': title.trim(),
          'resumo': _noticeSummary(trimmedContent),
          'conteudo': trimmedContent,
          'categoria': 'Pessoal',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  static Future<List<MemberNotice>> listMemberNotices(String memberId) async {
    _requireSupabase();
    final rows = await Supabase.instance.client
        .from('avisos_membros')
        .select()
        .eq('membro_id', memberId)
        .order('criado_em', ascending: false);
    return (rows as List)
        .map((row) => MemberNotice.fromDatabase(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<void> updateMemberNotice({
    required String noticeId,
    required String title,
    required String content,
  }) async {
    _requireSupabase();
    final trimmedContent = content.trim();
    await Supabase.instance.client
        .from('avisos_membros')
        .update({
          'titulo': title.trim(),
          'resumo': _noticeSummary(trimmedContent),
          'conteudo': trimmedContent,
        })
        .eq('id', noticeId);
  }

  static Future<void> deleteMemberNotice(String noticeId) async {
    _requireSupabase();
    await Supabase.instance.client
        .from('avisos_membros')
        .delete()
        .eq('id', noticeId);
  }

  static Future<void> markMemberNoticeViewed(String noticeId) async {
    _requireSupabase();
    await Supabase.instance.client
        .from('avisos_membros')
        .update({'visualizado_em': DateTime.now().toUtc().toIso8601String()})
        .eq('id', noticeId)
        .isFilter('visualizado_em', null);
  }

  static Future<void> markMemberNoticesViewed(
    Iterable<String> noticeIds,
  ) async {
    _requireSupabase();
    final ids = noticeIds.toSet().toList();
    if (ids.isEmpty) return;
    await Supabase.instance.client
        .from('avisos_membros')
        .update({'visualizado_em': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids)
        .isFilter('visualizado_em', null);
  }

  static String _noticeSummary(String content) =>
      content.length <= 140 ? content : '${content.substring(0, 137)}...';

  static Future<Map<String, dynamic>> sendMemberNoticePush(
    String noticeId,
  ) async {
    _requireSupabase();
    final response = await Supabase.instance.client.functions.invoke(
      'send-member-notice',
      body: {'noticeId': noticeId},
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return {'sent': false};
  }

  static Future<List<DepartmentAssignment>> listMyDepartmentAssignments(
    String userId,
  ) async {
    _requireSupabase();
    final client = Supabase.instance.client;
    final member = await client
        .from('membros')
        .select('id')
        .eq('usuario_id', userId)
        .single();
    final rows = await client
        .from('departamentos_membros')
        .select()
        .eq('membro_id', member['id'])
        .order('departamento_id')
        .order('cargo');
    return (rows as List)
        .map(
          (row) =>
              DepartmentAssignment.fromDatabase(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<List<DepartmentAssignment>> listDepartmentAssignments() async {
    _requireSupabase();
    final rows = await Supabase.instance.client
        .from('departamentos_membros')
        .select()
        .order('departamento_id')
        .order('cargo');
    return (rows as List)
        .map(
          (row) =>
              DepartmentAssignment.fromDatabase(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<List<DepartmentRosterMember>> listDepartmentRoster(
    String departmentId,
    String departmentName,
    String departmentDisplayName,
  ) async {
    _requireSupabase();
    final rows = await Supabase.instance.client.rpc(
      'listar_membros_departamento',
      params: {
        'p_departamento_id': departmentId,
        'p_departamento_nome': departmentName,
        'p_departamento_exibicao': departmentDisplayName,
      },
    );
    final storage = Supabase.instance.client.storage.from('fotos-membros');
    return Future.wait(
      (rows as List).map((value) async {
        final member = DepartmentRosterMember.fromDatabase(
          Map<String, dynamic>.from(value),
        );
        final photoPath = member.photoPath;
        if (photoPath == null || photoPath.isEmpty) return member;
        final photoUrl = await storage.createSignedUrl(photoPath, 3600);
        return member.copyWithPhotoUrl(photoUrl);
      }),
    );
  }

  static Future<List<DepartmentLeader>> listDepartmentLeaders(
    String departmentId,
    String fallbackName,
  ) async {
    final name = fallbackName.trim();
    if (!supabaseInicializado) {
      return name.isEmpty ? [] : [DepartmentLeader(name: name)];
    }

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      return name.isEmpty ? [] : [DepartmentLeader(name: name)];
    }

    final rows = await client.rpc(
      'listar_lideres_departamento',
      params: {'p_departamento_id': departmentId},
    );
    return (rows as List)
        .map(
          (row) =>
              DepartmentLeader.fromDatabase(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<String?> createMemberPhotoUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    _requireSupabase();
    return Supabase.instance.client.storage
        .from('fotos-membros')
        .createSignedUrl(path, 3600);
  }

  static Future<void> saveDepartmentAssignment(
    DepartmentAssignment assignment,
  ) async {
    _requireSupabase();
    final client = Supabase.instance.client;
    final role = assignment.role.trim();
    if (role.isEmpty) {
      throw ArgumentError.value(role, 'role', 'Informe a função.');
    }

    if (assignment.id.isEmpty) {
      await client
          .from('departamentos_membros')
          .upsert(
            assignment.toDatabase(),
            onConflict: 'departamento_id,membro_id,cargo',
          );
    } else {
      await client
          .from('departamentos_membros')
          .update({'cargo': role})
          .eq('id', assignment.id);
    }
  }

  static Future<void> deleteDepartmentAssignment(String id) async {
    _requireSupabase();
    await Supabase.instance.client
        .from('departamentos_membros')
        .delete()
        .eq('id', id);
  }

  static Future<List<MemberScheduleAssignment>> listMyMemberSchedules(
    String userId,
  ) async {
    _requireSupabase();
    final client = Supabase.instance.client;
    final member = await client
        .from('membros')
        .select('id')
        .eq('usuario_id', userId)
        .single();
    final rows = await client
        .from('escalas_membros')
        .select()
        .eq('membro_id', member['id'])
        .order('data');
    return (rows as List)
        .map(
          (row) => MemberScheduleAssignment.fromDatabase(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  static Future<List<MemberScheduleAssignment>> listMemberSchedules(
    String memberId,
    String departmentId,
  ) async {
    _requireSupabase();
    final rows = await Supabase.instance.client
        .from('escalas_membros')
        .select()
        .eq('membro_id', memberId)
        .eq('departamento_id', departmentId)
        .order('data');
    return (rows as List)
        .map(
          (row) => MemberScheduleAssignment.fromDatabase(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  static Future<void> saveMemberScheduleDates({
    required String memberId,
    required String departmentId,
    required String eventId,
    required DateTime month,
    required Set<DateTime> dates,
  }) async {
    _requireSupabase();
    final client = Supabase.instance.client;
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    String dateString(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final selected = dates.map(dateString).toSet();
    if (selected.isNotEmpty) {
      await client
          .from('escalas_membros')
          .upsert(
            selected
                .map(
                  (date) => {
                    'membro_id': memberId,
                    'departamento_id': departmentId,
                    'evento_id': eventId,
                    'data': date,
                  },
                )
                .toList(),
            onConflict: 'membro_id,departamento_id,evento_id,data',
          );
    }

    final existing = await client
        .from('escalas_membros')
        .select('id,data')
        .eq('membro_id', memberId)
        .eq('departamento_id', departmentId)
        .eq('evento_id', eventId)
        .gte('data', dateString(start))
        .lt('data', dateString(end));
    for (final row in existing as List) {
      if (!selected.contains(row['data'] as String)) {
        await client
            .from('escalas_membros')
            .delete()
            .eq('id', row['id'] as String);
      }
    }
  }

  /// Lista cadastros de membros; somente o RLS administrativo permite acesso.
  static Future<List<MemberRecord>> listMembers() async {
    _requireSupabase();
    final rows = await Supabase.instance.client
        .from('membros')
        .select()
        .order('nome');
    return (rows as List)
        .map((row) => MemberRecord.fromDatabase(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Lista contas cadastradas como visitantes, separadas dos membros.
  static Future<List<Map<String, dynamic>>> listVisitors() async {
    _requireSupabase();
    final rows = await Supabase.instance.client
        .from('visitantes')
        .select()
        .order('nome');
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Promove uma conta visitante a membro, deixando o acesso pendente.
  static Future<void> promoteVisitorToMember(String visitorId) async {
    _requireSupabase();
    final result = await Supabase.instance.client.rpc(
      'admin_promover_visitante_a_membro',
      params: {'p_visitante_id': visitorId},
    );
    if (result is! String || result.isEmpty) {
      throw StateError('O servidor não confirmou a promoção do visitante.');
    }
  }

  /// Converte um cadastro de membro vinculado em visitante sem excluir a conta.
  static Future<void> convertMemberToVisitor(String memberId) async {
    _requireSupabase();
    final result = await Supabase.instance.client.rpc(
      'admin_converter_membro_em_visitante',
      params: {'p_membro_id': memberId},
    );
    if (result is! String || result.isEmpty) {
      throw StateError('O servidor não confirmou a conversão do membro.');
    }
  }

  /// Remove a conta Auth de um visitante e os dados vinculados por cascata.
  static Future<void> deleteVisitorAccount(String visitorId) async {
    _requireSupabase();
    await Supabase.instance.client.rpc(
      'admin_excluir_visitante',
      params: {'p_visitante_id': visitorId},
    );
  }

  /// Lista apenas os nomes públicos dos membros ativos que escolheram o grupo.
  static Future<List<String>> listDepartmentMembers(
    String departmentName,
  ) async {
    _requireSupabase();
    final rows = await Supabase.instance.client.rpc(
      'listar_membros_departamento',
      params: {'nome_departamento': departmentName},
    );
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['nome_exibicao'] as String)
        .toList();
  }

  static Future<List<Department>> listDepartments() async {
    if (!supabaseInicializado) {
      return List<Department>.from(DataService.departments);
    }

    final rows = await Supabase.instance.client
        .from('departamentos')
        .select()
        .order('ordem', ascending: true)
        .order('nome', ascending: true);
    return (rows as List)
        .map((row) => Department.fromDatabase(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Insere ou atualiza um departamento; o RLS permite isso apenas a admins.
  static Future<void> saveDepartment(Department department) async {
    _requireSupabase();
    await Supabase.instance.client
        .from('departamentos')
        .upsert(department.toDatabase());
  }

  static Future<void> reorderDepartments(List<String> departmentIds) async {
    _requireSupabase();
    await Supabase.instance.client.rpc(
      'definir_ordem_departamentos',
      params: {'p_department_ids': departmentIds},
    );
  }

  /// Remove um departamento; vínculos de agenda ficam sem departamento.
  static Future<void> deleteDepartment(String id) async {
    _requireSupabase();
    await Supabase.instance.client.from('departamentos').delete().eq('id', id);
  }

  /// Insere ou atualiza um evento de agenda; o RLS verifica a função admin.
  static const int eventAttachmentMaxBytes = 20 * 1024 * 1024;
  static const String _eventAttachmentBucket = 'materiais-eventos';

  static Future<String?> saveScheduleEvent(
    ScheduleEvent event, {
    Uint8List? attachmentBytes,
    String? attachmentName,
    bool removeAttachment = false,
  }) async {
    _requireSupabase();
    if (attachmentBytes != null &&
        (attachmentName == null || attachmentName.trim().isEmpty)) {
      throw ArgumentError.value(
        attachmentName,
        'attachmentName',
        'Informe o nome do arquivo anexado.',
      );
    }
    if (attachmentBytes != null &&
        attachmentBytes.length > eventAttachmentMaxBytes) {
      throw ArgumentError.value(
        attachmentBytes.length,
        'attachmentBytes',
        'O anexo deve ter no máximo 20 MB.',
      );
    }

    final client = Supabase.instance.client;
    final storage = client.storage.from(_eventAttachmentBucket);
    String? uploadedPath;
    var eventToSave = event;
    if (attachmentBytes != null && attachmentName != null) {
      final fileName = attachmentName
          .trim()
          .split(RegExp(r'[/\\]'))
          .last
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final extension = fileName.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => throw ArgumentError.value(
          attachmentName,
          'attachmentName',
          'Anexe um PDF ou uma imagem JPG, PNG ou WEBP.',
        ),
      };
      final eventDirectory = event.id.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final storedName = '${DateTime.now().microsecondsSinceEpoch}_$fileName';
      uploadedPath = '$eventDirectory/$storedName';
      await storage.uploadBinary(
        uploadedPath,
        attachmentBytes,
        fileOptions: FileOptions(contentType: contentType),
      );
      eventToSave = event.copyWithAttachment(
        path: uploadedPath,
        name: fileName,
      );
    } else if (removeAttachment) {
      eventToSave = event.copyWithAttachment(clear: true);
    }

    try {
      await client.from('eventos_agenda').upsert(eventToSave.toDatabase());
    } catch (error) {
      if (uploadedPath != null) {
        try {
          await storage.remove([uploadedPath]);
        } catch (cleanupError) {
          throw StateError(
            'Não foi possível salvar o evento ($error) nem remover o arquivo '
            'temporário ($cleanupError).',
          );
        }
      }
      rethrow;
    }

    final oldPath = event.attachmentPath;
    if (oldPath != null && oldPath != eventToSave.attachmentPath) {
      try {
        final references = await client
            .from('eventos_agenda')
            .select('id')
            .eq('anexo_path', oldPath)
            .neq('id', event.id)
            .limit(1);
        if ((references as List).isEmpty) {
          await storage.remove([oldPath]);
        }
      } catch (error) {
        return 'O evento foi salvo, mas o anexo anterior não pôde ser '
            'removido do armazenamento: $error';
      }
    }
    return null;
  }

  static Future<void> sendAgendaNotification({
    required String eventId,
    required AgendaNotificationType type,
  }) async {
    _requireSupabase();
    final response = await Supabase.instance.client.functions.invoke(
      'notificar-agenda',
      body: {'eventId': eventId, 'type': type.name},
    );
    if (response.data is! Map || (response.data as Map)['sent'] != true) {
      throw StateError(
        'O servidor não confirmou o envio da notificação: ${response.data}',
      );
    }
  }

  static Future<String> createEventAttachmentUrl(
    String path, {
    bool download = false,
    String? fileName,
  }) {
    _requireSupabase();
    return Supabase.instance.client.storage
        .from(_eventAttachmentBucket)
        .createSignedUrl(
          path,
          300,
          download: download
              ? fileName == null
                    ? DownloadBehavior.withOriginalName
                    : DownloadBehavior.named(fileName)
              : null,
        );
  }

  /// Remove um evento da programação.
  static Future<String?> deleteScheduleEvent(String id) async {
    _requireSupabase();
    final client = Supabase.instance.client;
    final row = await client
        .from('eventos_agenda')
        .select('anexo_path')
        .eq('id', id)
        .maybeSingle();
    await client.from('eventos_agenda').delete().eq('id', id);
    final attachmentPath = row?['anexo_path'] as String?;
    if (attachmentPath != null) {
      try {
        final references = await client
            .from('eventos_agenda')
            .select('id')
            .eq('anexo_path', attachmentPath)
            .limit(1);
        if ((references as List).isEmpty) {
          await client.storage.from(_eventAttachmentBucket).remove([
            attachmentPath,
          ]);
        }
      } catch (error) {
        return 'O evento foi excluído, mas o anexo não pôde ser removido do '
            'armazenamento: $error';
      }
    }
    return null;
  }

  /// Cria ou atualiza um pré-cadastro sem guardar senha do membro.
  static Future<void> saveMember(MemberRecord member) async {
    _requireSupabase();
    final row = member.toDatabase();
    final conflictTarget = member.id == null ? 'email' : 'id';
    await Supabase.instance.client
        .from('membros')
        .upsert(row, onConflict: conflictTarget);
  }

  static Future<void> setMemberAccess(
    String memberId, {
    required bool authorized,
  }) async {
    _requireSupabase();
    await Supabase.instance.client
        .from('membros')
        .update({
          'ativo': authorized,
          'status_acesso': authorized ? 'autorizado' : 'bloqueado',
        })
        .eq('id', memberId);
  }

  /// Remove o cadastro de membro.
  static Future<void> deleteMember(String id) async {
    _requireSupabase();
    await Supabase.instance.client.from('membros').delete().eq('id', id);
  }

  static Future<void> saveScale(ScaleItem scale) async {
    throw UnsupportedError('O gerenciamento de escalas foi removido do app.');
  }

  static Future<void> deleteScale(String id) async {
    throw UnsupportedError('O gerenciamento de escalas foi removido do app.');
  }

  static Future<void> saveAnnouncement(Announcement announcement) async {
    throw UnsupportedError(
      'O gerenciamento de avisos internos foi removido do app.',
    );
  }

  static Future<void> deleteAnnouncement(String id) async {
    throw UnsupportedError(
      'O gerenciamento de avisos internos foi removido do app.',
    );
  }

  /// Importa exemplos apenas nas tabelas vazias, sem sobrescrever conteúdo.
  static Future<int> importEmptyTablesWithExamples() async {
    _requireSupabase();
    final client = Supabase.instance.client;
    var importedTables = 0;

    final departments = await client
        .from('departamentos')
        .select('id')
        .limit(1);
    if ((departments as List).isEmpty) {
      await client
          .from('departamentos')
          .upsert(
            DataService.departments.map((item) => item.toDatabase()).toList(),
          );
      importedTables++;
    }

    final events = await client.from('eventos_agenda').select('id').limit(1);
    if ((events as List).isEmpty) {
      final examples = [
        ...DataService.scheduleEvents,
        ...DataService.monthlySundayThemes.map(
          (event) => event.copyWithMonthlyTheme(),
        ),
      ];
      await client
          .from('eventos_agenda')
          .upsert(examples.map((item) => item.toDatabase()).toList());
      importedTables++;
    }

    return importedTables;
  }

  /// Evita falhas pouco claras ao tentar gravar sem Supabase configurado.
  static void _requireSupabase() {
    if (!supabaseInicializado) {
      throw StateError('Configure o Supabase antes de alterar o conteúdo.');
    }
  }
}

extension on ScheduleEvent {
  /// Marca como tema mensal sem alterar os dados estáticos originais.
  ScheduleEvent copyWithMonthlyTheme() => ScheduleEvent(
    id: id,
    title: title,
    subtitle: subtitle,
    time: time,
    eventDate: eventDate,
    daysDescription: daysDescription,
    dayOfWeek: dayOfWeek,
    location: location,
    type: type,
    departmentId: departmentId,
    recurringCycle: recurringCycle,
    icon: icon,
    color: color,
    notes: notes,
    monthlyTheme: true,
    attachmentPath: attachmentPath,
    attachmentName: attachmentName,
  );
}
