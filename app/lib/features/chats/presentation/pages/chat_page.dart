import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../data/message_model.dart';
import '../controllers/chat_controller.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.chatId, this.title});

  final String chatId;
  final String? title;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, _SenderMeta> _senderMetaById = <String, _SenderMeta>{};
  bool _isLoadingSenderMeta = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendMessage() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    final sent = await ref
        .read(chatControllerProvider(widget.chatId).notifier)
        .send(text);
    if (!mounted || !sent) return;

    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _ensureSenderMeta(List<MessageModel> messages) async {
    if (_isLoadingSenderMeta || messages.isEmpty) return;
    final ids = messages
        .map((message) => message.senderId.trim())
        .where((id) => id.isNotEmpty && !_senderMetaById.containsKey(id))
        .toSet();
    if (ids.isEmpty) return;

    _isLoadingSenderMeta = true;
    try {
      final client = ref.read(supabaseClientProvider);
      final loaded = await _loadProfilesByIds(client, ids);
      if (!mounted || loaded.isEmpty) return;
      setState(() => _senderMetaById.addAll(loaded));
    } catch (_) {
      // Best effort: la chat resta utilizzabile anche senza metadata profilo.
    } finally {
      _isLoadingSenderMeta = false;
    }
  }

  Future<Map<String, _SenderMeta>> _loadProfilesByIds(
    SupabaseClient client,
    Set<String> userIds,
  ) async {
    final byId = <String, _SenderMeta>{};

    final attempts = <({String idColumn, String avatarColumn})>[
      (idColumn: 'id', avatarColumn: 'avatar_url'),
      (idColumn: 'id', avatarColumn: 'avatarUrl'),
      (idColumn: 'user_id', avatarColumn: 'avatar_url'),
      (idColumn: 'user_id', avatarColumn: 'avatarUrl'),
    ];

    for (final attempt in attempts) {
      try {
        final rows = await client
            .from('profiles')
            .select('${attempt.idColumn},username,role,${attempt.avatarColumn}')
            .inFilter(attempt.idColumn, userIds.toList());
        final mapped = _rowsToMaps(rows);
        if (mapped.isEmpty) continue;
        for (final row in mapped) {
          final id = _string(row[attempt.idColumn]);
          if (id == null) continue;
          byId[id] = _SenderMeta(
            username: _string(row['username']),
            role: _string(row['role']),
            avatarUrl: _string(row[attempt.avatarColumn]),
          );
        }
        if (byId.isNotEmpty) return byId;
      } on PostgrestException catch (error) {
        if (!_isColumnError(error)) rethrow;
      }
    }

    return byId;
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

  bool _isColumnError(PostgrestException error) {
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        error.message.toLowerCase().contains('does not exist') ||
        error.message.toLowerCase().contains('column');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.chatId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final title = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : 'Chat';

    ref.listen<ChatState>(chatControllerProvider(widget.chatId), (
      previous,
      next,
    ) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(chatControllerProvider(widget.chatId).notifier).clearError();
      }
    });

    ref.listen<AsyncValue<List<MessageModel>>>(
      chatMessagesProvider(widget.chatId),
      (previous, next) {
        next.whenOrNull(
          data: (messages) {
            final previousCount = previous?.valueOrNull?.length ?? 0;
            if (messages.length > previousCount) {
              _scrollToBottom();
            }
            ref
                .read(chatControllerProvider(widget.chatId).notifier)
                .markIncomingAsRead(messages);
            _ensureSenderMeta(messages);
          },
          error: (error, _) {
            final previousError = previous?.hasError == true
                ? previous!.error
                : null;
            if (error != previousError) {
              _showSnack('Errore caricamento messaggi: $error');
            }
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F1530), Color(0xFF0B1020), Color(0xFF090C16)],
              ),
              border: Border.all(
                color: const Color(0xFF9A6BFF).withValues(alpha: 0.9),
                width: 1.15,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF905CFF).withValues(alpha: 0.36),
                  blurRadius: 26,
                  spreadRadius: -4,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _ChatHeader(
                  title: title,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: messagesAsync.when(
                    loading: () => const Center(child: SinapsyLogoLoader()),
                    error: (error, _) => _ChatLoadError(
                      error: '$error',
                      onRetry: () => ref.refresh(chatMessagesProvider(widget.chatId)),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) {
                        return const _EmptyChatState();
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMine =
                              state.currentUserId != null &&
                              message.senderId == state.currentUserId;
                          final senderMeta = _senderMetaById[message.senderId];
                          return _MessageBubble(
                            message: message,
                            isMine: isMine,
                            senderMeta: senderMeta,
                          );
                        },
                      );
                    },
                  ),
                ),
                _InputBar(
                  controller: _textController,
                  isSending: state.isSending,
                  onSend: _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: const Color(0xFFEAE0FF),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFEDE5FF),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.senderMeta,
  });

  final MessageModel message;
  final bool isMine;
  final _SenderMeta? senderMeta;

  @override
  Widget build(BuildContext context) {
    if (isMine) return _buildMineBubble(context);
    return _buildOtherBubble(context);
  }

  Widget _buildMineBubble(BuildContext context) {
    final bubbleGradient = const [Color(0xFF2A1950), Color(0xFF1B1235)];
    final bubbleBorder = const Color(0xFFB684FF).withValues(alpha: 0.82);
    final maxWidth = MediaQuery.of(context).size.width * 0.68;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bubbleGradient,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: bubbleBorder, width: 1.15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB684FF).withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      message.text,
                      style: const TextStyle(
                        color: Color(0xFFEAF0FF),
                        fontSize: 30 / 2,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _metaLabel(),
                    style: const TextStyle(
                      color: Color(0xFFB8C4DE),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtherBubble(BuildContext context) {
    final displayName = _displayName();
    final roleLabel = _roleLabel();
    final bubbleGradient = const [Color(0xFF1A2540), Color(0xFF121D32)];
    final bubbleBorder = const Color(0xFF5D73A5).withValues(alpha: 0.7);
    final maxWidth = MediaQuery.of(context).size.width * 0.68;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SenderAvatar(
            imageUrl: senderMeta?.avatarUrl,
            fallbackLabel: displayName,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFEDE7FF),
                          fontWeight: FontWeight.w700,
                          fontSize: 29 / 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(label: roleLabel),
                  ],
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: bubbleGradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: bubbleBorder, width: 1.15),
                      boxShadow: [
                        BoxShadow(
                          color: isMine
                              ? const Color(0xFFB684FF).withValues(alpha: 0.35)
                              : const Color(0xFF4D72D8).withValues(alpha: 0.28),
                          blurRadius: 12,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              message.text,
                              style: const TextStyle(
                                color: Color(0xFFEAF0FF),
                                fontSize: 30 / 2,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _metaLabel(),
                            style: const TextStyle(
                              color: Color(0xFFB8C4DE),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayName() {
    final username = senderMeta?.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    if (isMine) return 'Tu';
    return 'Creator';
  }

  String _roleLabel() {
    final raw = senderMeta?.role?.trim().toLowerCase() ?? '';
    if (raw.contains('brand')) return 'Brand';
    if (raw.contains('foto')) return 'Fotografo';
    if (raw.contains('creator') || raw.contains('service')) return 'Creator';
    return isMine ? 'Tu' : 'Creator';
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _metaLabel() {
    final time = _formatTime(message.createdAt);
    if (!isMine) return time;
    if (message.readAt == null) return time;
    return '$time • Visualizzato';
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.imageUrl, required this.fallbackLabel});

  final String? imageUrl;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final clean = imageUrl?.trim() ?? '';
    final letter = fallbackLabel.trim().isNotEmpty
        ? fallbackLabel.trim().substring(0, 1).toUpperCase()
        : 'C';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDCC8FF), width: 1.2),
        color: const Color(0xFFEEF1FA),
      ),
      child: ClipOval(
        child: clean.isNotEmpty
            ? Image.network(
                clean,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _SenderAvatarFallback(letter: letter),
              )
            : _SenderAvatarFallback(letter: letter),
      ),
    );
  }
}

class _SenderAvatarFallback extends StatelessWidget {
  const _SenderAvatarFallback({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFEDF2FF),
      child: Text(
        letter,
        style: const TextStyle(
          color: Color(0xFF1A2032),
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x4D6D3CE1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF8E6BE8).withValues(alpha: 0.9)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE9DFFF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF21113F), Color(0xFF15102A)],
          ),
          border: Border.all(
            color: const Color(0xFFB28BFF).withValues(alpha: 0.92),
            width: 1.15,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA16EFF).withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.attach_file_rounded,
                color: Color(0xFFD6C5FF),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.mic_none_rounded, color: Color(0xFFD6C5FF)),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                enabled: !isSending,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Scrivi un messaggio...',
                  hintStyle: const TextStyle(color: Color(0xFF9C90C2)),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(
                  color: Color(0xFFEAE5FF),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFC79AFF), Color(0xFF7D48EE)],
                ),
                border: Border.all(color: const Color(0xFFE8D6FF), width: 1.15),
              ),
              child: IconButton(
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: SinapsyLogoLoader(size: 18),
                      )
                    : const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF1A1131),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatLoadError extends StatelessWidget {
  const _ChatLoadError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Impossibile caricare i messaggi.',
              style: TextStyle(color: Color(0xFFE5ECFF)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9AA8C6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Nessun messaggio. Inizia la conversazione.',
        style: TextStyle(
          color: Color(0xFFD8E3FF),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _SenderMeta {
  const _SenderMeta({
    required this.username,
    required this.role,
    required this.avatarUrl,
  });

  final String? username;
  final String? role;
  final String? avatarUrl;
}
