class MessageModel {
  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final DateTime? readAt;

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['created_at'] ?? map['createdAt'];
    final createdAt =
        DateTime.tryParse((createdAtRaw ?? '').toString()) ??
        DateTime.now().toUtc();
    final readAtRaw = map['read_at'] ?? map['readAt'];
    final readAt = DateTime.tryParse((readAtRaw ?? '').toString());

    return MessageModel(
      id: (map['id'] ?? '').toString(),
      chatId: (map['chat_id'] ?? map['chatId'] ?? '').toString(),
      senderId: (map['sender_id'] ?? map['senderId'] ?? '').toString(),
      text: (map['text'] ?? map['body'] ?? '').toString(),
      createdAt: createdAt,
      readAt: readAt,
    );
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    DateTime? createdAt,
    DateTime? readAt,
    bool clearReadAt = false,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
    );
  }
}
