import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import 'message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  Future<List<BrandChatNotificationItem>> listBrandChatNotifications({
    required String brandId,
    int limit = 20,
  }) async {
    final cleanBrandId = brandId.trim();
    if (cleanBrandId.isEmpty) return const <BrandChatNotificationItem>[];

    final rows = await _queryBrandChatRows(brandId: cleanBrandId, limit: limit);
    if (rows.isEmpty) return const <BrandChatNotificationItem>[];

    final campaignIds = <String>{};
    final creatorIds = <String>{};
    for (final row in rows) {
      final campaignId = _string(row['campaign_id'] ?? row['campaignId']);
      if (campaignId != null) {
        campaignIds.add(campaignId);
      }
      final creatorId = _string(row['creator_id'] ?? row['creatorId']);
      if (creatorId != null) {
        creatorIds.add(creatorId);
      }
    }

    final campaignTitles = await _loadCampaignTitles(campaignIds);
    final creatorUsernames = await _loadCreatorUsernames(creatorIds);
    final creatorAvatarUrls = await _loadCreatorAvatarUrls(creatorIds);

    final items = <BrandChatNotificationItem>[];
    for (final row in rows) {
      final chatId = _string(row['id'] ?? row['chat_id'] ?? row['chatId']);
      if (chatId == null) continue;
      final campaignId = _string(row['campaign_id'] ?? row['campaignId']);
      final creatorId = _string(row['creator_id'] ?? row['creatorId']);
      final updatedAt = _dateTime(
        row['updated_at'] ??
            row['updatedAt'] ??
            row['created_at'] ??
            row['createdAt'],
      );
      final lastMessage = _string(row['last_message'] ?? row['lastMessage']);

      items.add(
        BrandChatNotificationItem(
          chatId: chatId,
          campaignId: campaignId,
          campaignTitle: campaignId == null ? null : campaignTitles[campaignId],
          creatorId: creatorId,
          creatorUsername: creatorId == null
              ? null
              : creatorUsernames[creatorId],
          creatorAvatarUrl: creatorId == null
              ? null
              : creatorAvatarUrls[creatorId],
          lastMessage: lastMessage,
          updatedAt: updatedAt,
        ),
      );
    }

    items.sort((a, b) {
      final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return items;
  }

  Future<List<CreatorChatNotificationItem>> listCreatorChatNotifications({
    required String creatorId,
    int limit = 20,
  }) async {
    final cleanCreatorId = creatorId.trim();
    if (cleanCreatorId.isEmpty) return const <CreatorChatNotificationItem>[];

    final rows = await _queryCreatorChatRows(
      creatorId: cleanCreatorId,
      limit: limit,
    );
    if (rows.isEmpty) return const <CreatorChatNotificationItem>[];

    final campaignIds = <String>{};
    final brandIds = <String>{};
    for (final row in rows) {
      final campaignId = _string(row['campaign_id'] ?? row['campaignId']);
      if (campaignId != null) {
        campaignIds.add(campaignId);
      }
      final brandId = _string(row['brand_id'] ?? row['brandId']);
      if (brandId != null) {
        brandIds.add(brandId);
      }
    }

    final campaignTitles = await _loadCampaignTitles(campaignIds);
    final brandUsernames = await _loadBrandUsernames(brandIds);
    final brandAvatarUrls = await _loadBrandAvatarUrls(brandIds);

    final items = <CreatorChatNotificationItem>[];
    for (final row in rows) {
      final chatId = _string(row['id'] ?? row['chat_id'] ?? row['chatId']);
      if (chatId == null) continue;
      final campaignId = _string(row['campaign_id'] ?? row['campaignId']);
      final brandId = _string(row['brand_id'] ?? row['brandId']);
      final updatedAt = _dateTime(
        row['updated_at'] ??
            row['updatedAt'] ??
            row['created_at'] ??
            row['createdAt'],
      );
      final lastMessage = _string(row['last_message'] ?? row['lastMessage']);

      items.add(
        CreatorChatNotificationItem(
          chatId: chatId,
          campaignId: campaignId,
          campaignTitle: campaignId == null ? null : campaignTitles[campaignId],
          brandId: brandId,
          brandUsername: brandId == null ? null : brandUsernames[brandId],
          brandAvatarUrl: brandId == null ? null : brandAvatarUrls[brandId],
          lastMessage: lastMessage,
          updatedAt: updatedAt,
        ),
      );
    }

    items.sort((a, b) {
      final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return items;
  }

  Stream<List<MessageModel>> getMessagesStream({required String chatId}) {
    _log('messages.stream.start chatId=$chatId');
    return _client
        .from('messages')
        .stream(primaryKey: const ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .map((rows) {
          final messages = rows.whereType<Map>().map((row) {
            final map = row.map((k, v) => MapEntry('$k', v));
            return MessageModel.fromMap(map);
          }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _log('messages.stream.data chatId=$chatId count=${messages.length}');
          return messages;
        });
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    _log(
      'messages.send.start chatId=$chatId senderId=$senderId len=${cleanText.length}',
    );

    try {
      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': senderId,
        'body': cleanText,
        'created_at': now,
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
      _log(
        'messages.send.column_fallback chatId=$chatId code=${error.code} msg=${error.message}',
      );
      try {
        await _client.from('messages').insert({
          'chat_id': chatId,
          'sender_id': senderId,
          'text': cleanText,
          'created_at': now,
        });
      } on PostgrestException catch (legacyError) {
        if (!_isColumnError(legacyError)) rethrow;
        await _client.from('messages').insert({
          'chatId': chatId,
          'senderId': senderId,
          'text': cleanText,
          'createdAt': now,
        });
      }
    }

    await _tryUpdateChatLastMessage(
      chatId: chatId,
      text: cleanText,
      nowIso: now,
    );
    _log('messages.send.success chatId=$chatId');
  }

  Future<void> markMessagesAsRead({
    required String chatId,
    required String readerId,
  }) async {
    final cleanChatId = chatId.trim();
    final cleanReaderId = readerId.trim();
    if (cleanChatId.isEmpty || cleanReaderId.isEmpty) return;

    try {
      await _client.rpc(
        'mark_chat_messages_read',
        params: {'p_chat_id': cleanChatId},
      );
      return;
    } on PostgrestException catch (error) {
      final canFallback =
          _isMissingRpc(error) ||
          _isColumnError(error) ||
          _isPermissionDenied(error);
      if (!canFallback) rethrow;
      _log(
        'messages.read.rpc_fallback chatId=$cleanChatId code=${error.code} msg=${error.message}',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final attempts = <_MarkReadAttempt>[
      const _MarkReadAttempt(
        chatColumn: 'chat_id',
        senderColumn: 'sender_id',
        readColumn: 'read_at',
      ),
      const _MarkReadAttempt(
        chatColumn: 'chat_id',
        senderColumn: 'senderId',
        readColumn: 'read_at',
      ),
      const _MarkReadAttempt(
        chatColumn: 'chatId',
        senderColumn: 'senderId',
        readColumn: 'readAt',
      ),
      const _MarkReadAttempt(
        chatColumn: 'chatId',
        senderColumn: 'sender_id',
        readColumn: 'readAt',
      ),
    ];

    PostgrestException? lastColumnError;
    for (final attempt in attempts) {
      try {
        await _client
            .from('messages')
            .update({attempt.readColumn: now})
            .eq(attempt.chatColumn, cleanChatId)
            .neq(attempt.senderColumn, cleanReaderId)
            .filter(attempt.readColumn, 'is', 'null');
        return;
      } on PostgrestException catch (error) {
        if (!_isColumnError(error) && !_isPermissionDenied(error)) rethrow;
        if (_isPermissionDenied(error)) return;
        lastColumnError = error;
      }
    }

    if (lastColumnError != null) throw lastColumnError;
  }

  Future<String> createChatForMatch({
    required String campaignId,
    required String brandId,
    required String creatorId,
  }) async {
    _log(
      'chat.create_or_get.start campaignId=$campaignId brandId=$brandId creatorId=$creatorId',
    );

    final existing = await getChatIdForMatch(
      campaignId: campaignId,
      brandId: brandId,
      creatorId: creatorId,
    );
    if (existing != null) {
      _log('chat.create_or_get.reuse chatId=$existing');
      return existing;
    }

    try {
      final projectId = await _findOrCreateProject(
        campaignId: campaignId,
        brandId: brandId,
        creatorId: creatorId,
      );
      final chatId = await _createChatForProject(projectId);
      _log('chat.create_or_get.created projectId=$projectId chatId=$chatId');
      return chatId;
    } on PostgrestException catch (error) {
      if (!_isColumnError(error) && !_isMissingTable(error)) rethrow;
      _log(
        'chat.create_or_get.project_schema_unavailable code=${error.code} msg=${error.message}',
      );
    }

    final legacyChatId = await _createLegacyChat(
      campaignId: campaignId,
      brandId: brandId,
      creatorId: creatorId,
    );
    _log('chat.create_or_get.legacy_created chatId=$legacyChatId');
    return legacyChatId;
  }

  Future<String?> getChatIdForMatch({
    required String campaignId,
    required String brandId,
    required String creatorId,
  }) async {
    final projectId = await _findProjectId(
      campaignId: campaignId,
      brandId: brandId,
      creatorId: creatorId,
    );
    if (projectId != null) {
      final byProject = await _findChatIdByProject(projectId);
      if (byProject != null) return byProject;
    }

    return _findExistingLegacyChat(
      campaignId: campaignId,
      brandId: brandId,
      creatorId: creatorId,
    );
  }

  Future<String?> _findProjectId({
    required String campaignId,
    required String brandId,
    required String creatorId,
  }) async {
    try {
      final row = await _client
          .from('projects')
          .select('id')
          .eq('campaign_id', campaignId)
          .eq('brand_id', brandId)
          .eq('partner_id', creatorId)
          .maybeSingle();
      return _readId(row);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error) && !_isMissingTable(error)) rethrow;
      return null;
    }
  }

  Future<String> _findOrCreateProject({
    required String campaignId,
    required String brandId,
    required String creatorId,
  }) async {
    final existing = await _findProjectId(
      campaignId: campaignId,
      brandId: brandId,
      creatorId: creatorId,
    );
    if (existing != null) return existing;

    final now = DateTime.now().toUtc().toIso8601String();
    final payloads = <Map<String, dynamic>>[
      {
        'campaign_id': campaignId,
        'brand_id': brandId,
        'partner_id': creatorId,
        'status': 'in_progress',
        'created_at': now,
      },
      {
        'campaign_id': campaignId,
        'brand_id': brandId,
        'partner_id': creatorId,
        'status': 'in_progress',
      },
      {'campaign_id': campaignId, 'brand_id': brandId, 'partner_id': creatorId},
    ];

    PostgrestException? lastColumnError;
    for (final payload in payloads) {
      try {
        final created = await _client
            .from('projects')
            .insert(payload)
            .select('id')
            .single();
        final projectId = _readId(created);
        if (projectId == null) {
          throw StateError('Project id non disponibile dopo la creazione.');
        }
        return projectId;
      } on PostgrestException catch (error) {
        if (!_isColumnError(error)) rethrow;
        lastColumnError = error;
        _log(
          'project.create.column_fallback code=${error.code} msg=${error.message}',
        );
      }
    }

    if (lastColumnError != null) throw lastColumnError;
    throw StateError('Impossibile creare project per la chat.');
  }

  Future<String?> _findChatIdByProject(String projectId) async {
    try {
      final row = await _client
          .from('chats')
          .select('id')
          .eq('project_id', projectId)
          .maybeSingle();
      return _readId(row);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error) && !_isMissingTable(error)) rethrow;
      return null;
    }
  }

  Future<String> _createChatForProject(String projectId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final created = await _client
          .from('chats')
          .insert({'project_id': projectId, 'created_at': now})
          .select('id')
          .single();
      final chatId = _readId(created);
      if (chatId == null) {
        throw StateError('Chat id non disponibile dopo la creazione.');
      }
      return chatId;
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
      final created = await _client
          .from('chats')
          .insert({'project_id': projectId})
          .select('id')
          .single();
      final chatId = _readId(created);
      if (chatId == null) {
        throw StateError('Chat id non disponibile dopo la creazione.');
      }
      return chatId;
    }
  }

  Future<String?> _findExistingLegacyChat({
    required String campaignId,
    required String brandId,
    required String creatorId,
  }) async {
    try {
      final result = await _client
          .from('chats')
          .select('id')
          .eq('campaign_id', campaignId)
          .eq('brand_id', brandId)
          .eq('creator_id', creatorId)
          .maybeSingle();
      return _readId(result);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error) && !_isMissingTable(error)) rethrow;
    }

    try {
      final result = await _client
          .from('chats')
          .select('id')
          .eq('campaignId', campaignId)
          .eq('brandId', brandId)
          .eq('creatorId', creatorId)
          .maybeSingle();
      return _readId(result);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error) && !_isMissingTable(error)) rethrow;
    }

    return null;
  }

  Future<String> _createLegacyChat({
    required String campaignId,
    required String brandId,
    required String creatorId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final payloads = <Map<String, dynamic>>[
      {
        'campaign_id': campaignId,
        'collab_id': campaignId,
        'brand_id': brandId,
        'creator_id': creatorId,
        'updated_at': now,
      },
      {'campaign_id': campaignId, 'brand_id': brandId, 'creator_id': creatorId},
      {
        'campaignId': campaignId,
        'collabId': campaignId,
        'brandId': brandId,
        'creatorId': creatorId,
        'updatedAt': now,
      },
      {'campaignId': campaignId, 'brandId': brandId, 'creatorId': creatorId},
    ];

    PostgrestException? lastColumnError;
    for (final payload in payloads) {
      try {
        final created = await _client
            .from('chats')
            .insert(payload)
            .select()
            .single();
        final chatId = _readId(created);
        if (chatId == null) {
          throw StateError('Chat id non disponibile dopo la creazione.');
        }
        return chatId;
      } on PostgrestException catch (error) {
        if (!_isColumnError(error)) rethrow;
        lastColumnError = error;
      }
    }

    if (lastColumnError != null) throw lastColumnError;
    throw StateError('Impossibile creare chat.');
  }

  Future<void> _tryUpdateChatLastMessage({
    required String chatId,
    required String text,
    required String nowIso,
  }) async {
    try {
      await _client
          .from('chats')
          .update({'last_message': text, 'updated_at': nowIso})
          .eq('id', chatId);
      return;
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      await _client
          .from('chats')
          .update({'lastMessage': text, 'updatedAt': nowIso})
          .eq('chatId', chatId);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
      _log('chat.last_message.skip chatId=$chatId code=${error.code}');
    }
  }

  Future<List<Map<String, dynamic>>> _queryBrandChatRows({
    required String brandId,
    required int limit,
  }) async {
    try {
      final rows = await _client
          .from('chats')
          .select('*')
          .eq('brand_id', brandId)
          .order('updated_at', ascending: false)
          .limit(limit);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('chats')
          .select('*')
          .eq('brand_id', brandId)
          .order('created_at', ascending: false)
          .limit(limit);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('chats')
          .select('*')
          .eq('brandId', brandId)
          .order('updatedAt', ascending: false)
          .limit(limit);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('chats')
          .select('*')
          .eq('brandId', brandId)
          .order('createdAt', ascending: false)
          .limit(limit);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _queryCreatorChatRows({
    required String creatorId,
    required int limit,
  }) async {
    try {
      final rows = await _client
          .from('chats')
          .select('*')
          .eq('creator_id', creatorId)
          .order('updated_at', ascending: false)
          .limit(limit);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('chats')
          .select('*')
          .eq('creator_id', creatorId)
          .order('created_at', ascending: false)
          .limit(limit);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('chats')
          .select('*')
          .eq('creatorId', creatorId)
          .order('updatedAt', ascending: false)
          .limit(limit);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('chats')
          .select('*')
          .eq('creatorId', creatorId)
          .order('createdAt', ascending: false)
          .limit(limit);
      return _rowsToMaps(rows);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, String>> _loadCampaignTitles(
    Set<String> campaignIds,
  ) async {
    if (campaignIds.isEmpty) return const <String, String>{};

    try {
      final rows = await _client
          .from('campaigns')
          .select('id,title')
          .inFilter('id', campaignIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['id']);
        final title = _string(row['title']);
        if (id != null && title != null) {
          acc[id] = title;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('campaigns')
          .select('id,name')
          .inFilter('id', campaignIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['id']);
        final title = _string(row['name']);
        if (id != null && title != null) {
          acc[id] = title;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    final rows = await _client
        .from('campaigns')
        .select('id,headline')
        .inFilter('id', campaignIds.toList());
    return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
      acc,
      row,
    ) {
      final id = _string(row['id']);
      final title = _string(row['headline']);
      if (id != null && title != null) {
        acc[id] = title;
      }
      return acc;
    });
  }

  Future<Map<String, String>> _loadCreatorUsernames(
    Set<String> creatorIds,
  ) async {
    if (creatorIds.isEmpty) return const <String, String>{};

    try {
      final rows = await _client
          .from('profiles')
          .select('id,username')
          .inFilter('id', creatorIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['id']);
        final username = _string(row['username']);
        if (id != null && username != null) {
          acc[id] = username;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('profiles')
          .select('user_id,username')
          .inFilter('user_id', creatorIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['user_id']);
        final username = _string(row['username']);
        if (id != null && username != null) {
          acc[id] = username;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
      return const <String, String>{};
    }
  }

  Future<Map<String, String>> _loadCreatorAvatarUrls(
    Set<String> creatorIds,
  ) async {
    if (creatorIds.isEmpty) return const <String, String>{};

    final avatarColumns = <String>['avatar_url', 'avatarUrl'];
    final idColumns = <String>['id', 'user_id'];

    for (final idColumn in idColumns) {
      for (final avatarColumn in avatarColumns) {
        try {
          final rows = await _client
              .from('profiles')
              .select('$idColumn,$avatarColumn')
              .inFilter(idColumn, creatorIds.toList());
          return _rowsToMaps(rows).fold<Map<String, String>>(
            <String, String>{},
            (acc, row) {
              final id = _string(row[idColumn]);
              final avatar = _string(row[avatarColumn]);
              if (id != null && avatar != null) {
                acc[id] = avatar;
              }
              return acc;
            },
          );
        } on PostgrestException catch (error) {
          if (!_isColumnError(error)) rethrow;
        }
      }
    }

    return const <String, String>{};
  }

  Future<Map<String, String>> _loadBrandUsernames(Set<String> brandIds) async {
    if (brandIds.isEmpty) return const <String, String>{};

    try {
      final rows = await _client
          .from('profiles')
          .select('id,username')
          .inFilter('id', brandIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['id']);
        final username = _string(row['username']);
        if (id != null && username != null) {
          acc[id] = username;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }

    try {
      final rows = await _client
          .from('profiles')
          .select('user_id,username')
          .inFilter('user_id', brandIds.toList());
      return _rowsToMaps(rows).fold<Map<String, String>>(<String, String>{}, (
        acc,
        row,
      ) {
        final id = _string(row['user_id']);
        final username = _string(row['username']);
        if (id != null && username != null) {
          acc[id] = username;
        }
        return acc;
      });
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
      return const <String, String>{};
    }
  }

  Future<Map<String, String>> _loadBrandAvatarUrls(Set<String> brandIds) async {
    if (brandIds.isEmpty) return const <String, String>{};

    final avatarColumns = <String>['avatar_url', 'avatarUrl'];
    final idColumns = <String>['id', 'user_id'];

    for (final idColumn in idColumns) {
      for (final avatarColumn in avatarColumns) {
        try {
          final rows = await _client
              .from('profiles')
              .select('$idColumn,$avatarColumn')
              .inFilter(idColumn, brandIds.toList());
          return _rowsToMaps(rows).fold<Map<String, String>>(
            <String, String>{},
            (acc, row) {
              final id = _string(row[idColumn]);
              final avatar = _string(row[avatarColumn]);
              if (id != null && avatar != null) {
                acc[id] = avatar;
              }
              return acc;
            },
          );
        } on PostgrestException catch (error) {
          if (!_isColumnError(error)) rethrow;
        }
      }
    }

    return const <String, String>{};
  }

  List<Map<String, dynamic>> _rowsToMaps(dynamic rows) {
    final raw = rows is List ? rows : const <dynamic>[];
    return raw.whereType<Object>().map(_toMap).toList();
  }

  Map<String, dynamic> _toMap(Object row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) {
      return row.map((key, value) => MapEntry('$key', value));
    }
    return <String, dynamic>{};
  }

  String? _string(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  DateTime? _dateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String? _readId(dynamic row) {
    if (row == null) return null;
    if (row is Map<String, dynamic>) {
      final id =
          (row['id'] ??
                  row['chat_id'] ??
                  row['chatId'] ??
                  row['project_id'] ??
                  '')
              .toString();
      if (id.isEmpty) return null;
      return id;
    }
    if (row is Map) {
      final id =
          (row['id'] ??
                  row['chat_id'] ??
                  row['chatId'] ??
                  row['project_id'] ??
                  '')
              .toString();
      if (id.isEmpty) return null;
      return id;
    }
    return null;
  }

  bool _isColumnError(PostgrestException error) {
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        _messageContainsSqlState(error, '42703') ||
        error.message.toLowerCase().contains('does not exist') ||
        error.message.toLowerCase().contains('column');
  }

  bool _isMissingTable(PostgrestException error) {
    return error.code == '42P01' ||
        error.code == 'PGRST205' ||
        _messageContainsSqlState(error, '42P01') ||
        error.message.toLowerCase().contains('relation') &&
            error.message.toLowerCase().contains('does not exist');
  }

  bool _isMissingRpc(PostgrestException error) {
    return error.code == '42883' ||
        error.message.toLowerCase().contains('function') ||
        error.message.toLowerCase().contains('rpc');
  }

  bool _isPermissionDenied(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42501' ||
        _messageContainsSqlState(error, '42501') ||
        message.contains('row-level security') ||
        message.contains('forbidden') ||
        message.contains('permission denied');
  }

  bool _messageContainsSqlState(PostgrestException error, String sqlState) {
    final message = error.message;
    return message.contains('"code":"$sqlState"') ||
        message.contains('"code": "$sqlState"');
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[ChatRepository] $message');
  }
}

class BrandChatNotificationItem {
  const BrandChatNotificationItem({
    required this.chatId,
    this.campaignId,
    this.campaignTitle,
    this.creatorId,
    this.creatorUsername,
    this.creatorAvatarUrl,
    this.lastMessage,
    this.updatedAt,
  });

  final String chatId;
  final String? campaignId;
  final String? campaignTitle;
  final String? creatorId;
  final String? creatorUsername;
  final String? creatorAvatarUrl;
  final String? lastMessage;
  final DateTime? updatedAt;
}

class CreatorChatNotificationItem {
  const CreatorChatNotificationItem({
    required this.chatId,
    this.campaignId,
    this.campaignTitle,
    this.brandId,
    this.brandUsername,
    this.brandAvatarUrl,
    this.lastMessage,
    this.updatedAt,
  });

  final String chatId;
  final String? campaignId;
  final String? campaignTitle;
  final String? brandId;
  final String? brandUsername;
  final String? brandAvatarUrl;
  final String? lastMessage;
  final DateTime? updatedAt;
}

class _MarkReadAttempt {
  const _MarkReadAttempt({
    required this.chatColumn,
    required this.senderColumn,
    required this.readColumn,
  });

  final String chatColumn;
  final String senderColumn;
  final String readColumn;
}
