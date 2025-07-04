class Chat {
  final String id;
  final List<String> participants;
  final String type;
  final String? relatedBookingId;
  final String lastMessage;
  final DateTime lastTime;

  Chat({
    required this.id,
    required this.participants,
    required this.type,
    this.relatedBookingId,
    required this.lastMessage,
    required this.lastTime,
  });

  factory Chat.fromMap(String id, Map<String, dynamic> map) => Chat(
    id: id,
    participants: List<String>.from(map['participants'] ?? []),
    type: map['type'] ?? '',
    relatedBookingId: map['relatedBookingId'],
    lastMessage: map['lastMessage'] ?? '',
    lastTime: (map['lastTime'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toMap() => {
    'participants': participants,
    'type': type,
    'relatedBookingId': relatedBookingId,
    'lastMessage': lastMessage,
    'lastTime': lastTime,
  };
}
