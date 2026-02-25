import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/chat_repository.dart';
import '../../data/message_model.dart';

final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<MessageModel>, String>((ref, chatId) {
      return ref.watch(chatRepositoryProvider).getMessagesStream(chatId: chatId);
    });

final chatControllerProvider =
    StateNotifierProvider.autoDispose.family<ChatController, ChatState, String>(
        (ref, chatId) {
      return ChatController(
        chatId: chatId,
        chatRepository: ref.watch(chatRepositoryProvider),
        authRepository: ref.watch(authRepositoryProvider),
      );
    });

class ChatState {
  const ChatState({
    this.currentUserId,
    this.isSending = false,
    this.errorMessage,
  });

  final String? currentUserId;
  final bool isSending;
  final String? errorMessage;

  ChatState copyWith({
    String? currentUserId,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      currentUserId: currentUserId ?? this.currentUserId,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required String chatId,
    required ChatRepository chatRepository,
    required AuthRepository authRepository,
  })  : _chatId = chatId,
        _chatRepository = chatRepository,
        _authRepository = authRepository,
        super(ChatState(currentUserId: authRepository.currentUser?.id));

  final String _chatId;
  final ChatRepository _chatRepository;
  final AuthRepository _authRepository;

  Future<bool> send(String text) async {
    final senderId = _authRepository.currentUser?.id ?? state.currentUserId;
    if (senderId == null) {
      state = state.copyWith(
        errorMessage: 'Sessione non valida. Effettua nuovamente il login.',
      );
      return false;
    }

    if (state.currentUserId != senderId) {
      state = state.copyWith(currentUserId: senderId);
    }

    final cleanText = text.trim();
    if (cleanText.isEmpty) return false;

    state = state.copyWith(isSending: true, clearError: true);
    try {
      await _chatRepository.sendMessage(
        chatId: _chatId,
        senderId: senderId,
        text: cleanText,
      );
      state = state.copyWith(
        isSending: false,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Invio messaggio fallito: $error',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
