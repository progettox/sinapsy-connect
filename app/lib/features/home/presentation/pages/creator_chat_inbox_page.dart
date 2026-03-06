import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../chats/data/chat_repository.dart';
import '../../../chats/presentation/pages/chat_page.dart';

class CreatorChatInboxPage extends ConsumerStatefulWidget {
  const CreatorChatInboxPage({super.key});

  @override
  ConsumerState<CreatorChatInboxPage> createState() =>
      _CreatorChatInboxPageState();
}

class _CreatorChatInboxPageState extends ConsumerState<CreatorChatInboxPage> {
  bool _isLoading = false;
  String? _error;
  List<CreatorChatNotificationItem> _items =
      const <CreatorChatNotificationItem>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadChats);
  }

  Future<void> _loadChats() async {
    final creatorId = ref.read(authRepositoryProvider).currentUser?.id.trim();
    if (creatorId == null || creatorId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _items = const <CreatorChatNotificationItem>[];
        _error = 'Sessione non valida.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final chats = await ref
          .read(chatRepositoryProvider)
          .listCreatorChatNotifications(creatorId: creatorId, limit: 100);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _items = chats;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Errore caricamento chat: $error';
      });
    }
  }

  Future<void> _openChat(CreatorChatNotificationItem item) async {
    final title = _usernameFor(item);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(chatId: item.chatId, title: title),
      ),
    );
    await _loadChats();
  }

  String _usernameFor(CreatorChatNotificationItem item) {
    final username = item.brandUsername?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    return 'brand';
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'ora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LuxuryNeonBackdrop()),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadChats,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                children: [
                  Row(
                    children: [
                      Text(
                        'Messaggi',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.colorTextPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _isLoading ? null : _loadChats,
                        tooltip: 'Aggiorna',
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xA6141823),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.colorStrokeSubtle.withValues(
                          alpha: 0.92,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Color(0xFFAAB7D4),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Cerca chat',
                          style: TextStyle(
                            color: Color(0xFF93A2C0),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isLoading && _items.isEmpty)
                    const SizedBox(
                      height: 180,
                      child: Center(child: SinapsyLogoLoader()),
                    )
                  else if (_error != null)
                    _InboxErrorState(error: _error!, onRetry: _loadChats)
                  else if (_items.isEmpty)
                    const _EmptyInboxState()
                  else
                    ..._items.map((item) {
                      return _ChatInboxTile(
                        item: item,
                        username: _usernameFor(item),
                        subtitle: item.lastMessage?.trim().isNotEmpty == true
                            ? item.lastMessage!.trim()
                            : (item.campaignTitle?.trim().isNotEmpty == true
                                  ? item.campaignTitle!.trim()
                                  : 'Apri chat'),
                        timeLabel: _timeLabel(item.updatedAt),
                        onTap: () => _openChat(item),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInboxTile extends StatelessWidget {
  const _ChatInboxTile({
    required this.item,
    required this.username,
    required this.subtitle,
    required this.timeLabel,
    required this.onTap,
  });

  final CreatorChatNotificationItem item;
  final String username;
  final String subtitle;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActiveNow =
        item.updatedAt != null &&
        DateTime.now().difference(item.updatedAt!.toLocal()).inMinutes <= 10;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          child: Row(
            children: [
              _ChatAvatar(
                imageUrl: item.brandAvatarUrl,
                label: username,
                isActiveNow: isActiveNow,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF0F4FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9AA8C7),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeLabel,
                style: const TextStyle(
                  color: Color(0xFF8C9AB9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.imageUrl,
    required this.label,
    required this.isActiveNow,
  });

  final String? imageUrl;
  final String label;
  final bool isActiveNow;

  @override
  Widget build(BuildContext context) {
    final clean = imageUrl?.trim() ?? '';
    final initial = label.replaceAll('@', '').trim();
    final letter = initial.isNotEmpty ? initial[0].toUpperCase() : 'B';

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF58529),
                  Color(0xFFDD2A7B),
                  Color(0xFF8134AF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: clean.isNotEmpty
                  ? Image.network(
                      clean,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _AvatarFallback(letter: letter),
                    )
                  : _AvatarFallback(letter: letter),
            ),
          ),
          if (isActiveNow)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF38D46E),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF090C13), width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF151C2B),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Color(0xFFE8EEFF),
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _InboxErrorState extends StatelessWidget {
  const _InboxErrorState({required this.error, required this.onRetry});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.colorStatusDanger),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
}

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 36),
      child: Column(
        children: [
          Icon(
            Icons.mark_chat_unread_outlined,
            size: 34,
            color: Color(0xFF8FA0C4),
          ),
          SizedBox(height: 12),
          Text(
            'Nessuna chat attiva.',
            style: TextStyle(
              color: Color(0xFFDCE6FF),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Le chat compaiono quando un brand accetta la tua candidatura.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9AA7C2),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
