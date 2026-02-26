import 'package:cloud_firestore/cloud_firestore.dart';

/// نموذج المستخدم
class ChatUser {
  final String id;
  final String name;
  final String phone;
  final String role; // customer, provider, owner
  final String? imageUrl;
  final String? fcmToken;

  ChatUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.imageUrl,
    this.fcmToken,
  });

  factory ChatUser.fromMap(Map<String, dynamic> map, String id) {
    return ChatUser(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['accountType'] ?? map['role'] ?? 'customer',
      imageUrl: map['imageUrl'] ?? map['profileImage'],
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'role': role,
      'imageUrl': imageUrl,
      'fcmToken': fcmToken,
    };
  }
}

/// نموذج غرفة المحادثة
class ChatRoom {
  final String id;
  final List<String> userIds;
  final Map<String, dynamic> userInfo; // معلومات المستخدمين {userId: {name, imageUrl}}
  final String? lastMessage;
  final DateTime? lastTimestamp;
  final String? lastSenderId;
  final Map<String, int> unreadCount; // عدد الرسائل غير المقروءة لكل مستخدم
  final Map<String, bool>? deletedBy; // المستخدمين الذين حذفوا المحادثة
  final Map<String, bool>? blockedBy; // المستخدمين المحظورين

  ChatRoom({
    required this.id,
    required this.userIds,
    required this.userInfo,
    this.lastMessage,
    this.lastTimestamp,
    this.lastSenderId,
    Map<String, int>? unreadCount,
    this.deletedBy,
    this.blockedBy,
  }) : unreadCount = unreadCount ?? {};

  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    return ChatRoom(
      id: id,
      userIds: List<String>.from(map['users'] ?? []),
      userInfo: Map<String, dynamic>.from(map['userInfo'] ?? {}),
      lastMessage: map['lastMessage'],
      lastTimestamp: map['lastTimestamp'] != null 
          ? (map['lastTimestamp'] as Timestamp).toDate()
          : null,
      lastSenderId: map['lastSenderId'],
      unreadCount: map['unreadCount'] != null 
          ? Map<String, int>.from(map['unreadCount'])
          : {},
      deletedBy: map['deletedBy'] != null
          ? Map<String, bool>.from(map['deletedBy'])
          : null,
      blockedBy: map['blockedBy'] != null
          ? Map<String, bool>.from(map['blockedBy'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'users': userIds,
      'userInfo': userInfo,
      'lastMessage': lastMessage,
      'lastTimestamp': lastTimestamp != null 
          ? Timestamp.fromDate(lastTimestamp!)
          : FieldValue.serverTimestamp(),
      'lastSenderId': lastSenderId,
      'unreadCount': unreadCount,
      'deletedBy': deletedBy,
      'blockedBy': blockedBy,
    };
  }

  /// الحصول على معلومات المستخدم الآخر
  Map<String, dynamic>? getOtherUserInfo(String currentUserId) {
    final otherUserId = userIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    return otherUserId.isNotEmpty ? userInfo[otherUserId] : null;
  }

  /// الحصول على معرف المستخدم الآخر
  String getOtherUserId(String currentUserId) {
    return userIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }
}

/// نموذج الرسالة
class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final List<String> readBy;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final String? audioUrl;
  final int? audioDuration;
  final Map<String, dynamic>? location; // {latitude, longitude, address}
  final bool? isDeleted;
  final String? replyToMessageId;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.type,
    List<String>? readBy,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.audioUrl,
    this.audioDuration,
    this.location,
    this.isDeleted,
    this.replyToMessageId,
  }) : readBy = readBy ?? [];

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['type']}',
        orElse: () => MessageType.text,
      ),
      readBy: List<String>.from(map['readBy'] ?? []),
      imageUrl: map['imageUrl'],
      fileUrl: map['fileUrl'],
      fileName: map['fileName'],
      audioUrl: map['audioUrl'],
      audioDuration: map['audioDuration'],
      location: map['location'] != null
          ? Map<String, dynamic>.from(map['location'])
          : null,
      isDeleted: map['isDeleted'],
      replyToMessageId: map['replyToMessageId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.toString().split('.').last,
      'readBy': readBy,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'audioUrl': audioUrl,
      'audioDuration': audioDuration,
      'location': location,
      'isDeleted': isDeleted,
      'replyToMessageId': replyToMessageId,
    };
  }

  /// نسخ الرسالة مع تعديلات
  Message copyWith({
    List<String>? readBy,
    bool? isDeleted,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      text: text,
      timestamp: timestamp,
      type: type,
      readBy: readBy ?? this.readBy,
      imageUrl: imageUrl,
      fileUrl: fileUrl,
      fileName: fileName,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      location: location,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToMessageId: replyToMessageId,
    );
  }
}

/// أنواع الرسائل
enum MessageType {
  text,
  image,
  file,
  audio,
  location,
}
