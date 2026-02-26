import 'package:cloud_firestore/cloud_firestore.dart';

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
    timestamp: (map['timestamp'] is Timestamp)
        ? (map['timestamp'] as Timestamp).toDate()
        : DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now(),
    read: map['read'] ?? false,
    attachmentUrl: map['attachmentUrl'],
  );

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'content': content,
    'timestamp': Timestamp.fromDate(timestamp),
    'read': read,
    'attachmentUrl': attachmentUrl,
  };
}
