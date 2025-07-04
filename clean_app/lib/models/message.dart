class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final bool read;
  final String? attachmentUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.read,
    this.attachmentUrl,
  });

  factory Message.fromMap(String id, Map<String, dynamic> map) => Message(
    id: id,
    senderId: map['senderId'] ?? '',
    content: map['content'] ?? '',
    timestamp: (map['timestamp'] as Timestamp).toDate(),
    read: map['read'] ?? false,
    attachmentUrl: map['attachmentUrl'],
  );

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'content': content,
    'timestamp': timestamp,
    'read': read,
    'attachmentUrl': attachmentUrl,
  };
}
