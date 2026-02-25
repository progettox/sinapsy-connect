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
      return null;
    }
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
    return error.code == '42703' || error.code == 'PGRST204';
  }

  bool _isMissingTable(PostgrestException error) {
    return error.code == '42P01' || error.code == 'PGRST205';
  }

  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[ChatRepository] $message');
  }
}
