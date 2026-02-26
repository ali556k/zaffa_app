import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';
import 'dart:async';

/// خدمة إدارة المحادثات
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إنشاء أو الحصول على غرفة محادثة
  Future<String> getOrCreateChatRoom({
    required String currentUserId,
    required String otherUserId,
    required Map<String, dynamic> currentUserInfo,
    required Map<String, dynamic> otherUserInfo,
  }) async {
    try {
      // التحقق من وجود محادثة موجودة
      final existingChat = await _firestore
          .collection('chats')
          .where('users', arrayContains: currentUserId)
          .get();

      for (var doc in existingChat.docs) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        if (users.contains(otherUserId)) {
          print('✅ تم العثور على محادثة موجودة: ${doc.id}');

          // تحديث معلومات المستخدمين (في حالة تغيرت serviceName أو imageUrl)
          await doc.reference.update({
            'userInfo.$currentUserId': currentUserInfo,
            'userInfo.$otherUserId': otherUserInfo,
          });
          print('✅ تم تحديث معلومات المستخدمين في المحادثة');

          // إذا كانت المحادثة محذوفة من قبل المستخدم الحالي، قم بإلغاء الحذف
          final deletedBy = doc.data()['deletedBy'] as Map<String, dynamic>?;
          if (deletedBy != null && deletedBy[currentUserId] == true) {
            await doc.reference.update({
              'deletedBy.$currentUserId': FieldValue.delete(),
            });
          }

          return doc.id;
        }
      }

      // إنشاء محادثة جديدة
      print('🆕 إنشاء محادثة جديدة بين $currentUserId و $otherUserId');
      final chatDoc = await _firestore.collection('chats').add({
        'users': [currentUserId, otherUserId],
        'userInfo': {
          currentUserId: currentUserInfo,
          otherUserId: otherUserInfo,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': null,
        'unreadCount': {currentUserId: 0, otherUserId: 0},
      });

      print('✅ تم إنشاء محادثة جديدة: ${chatDoc.id}');
      return chatDoc.id;
    } catch (e) {
      print('❌ خطأ في إنشاء/جلب المحادثة: $e');
      rethrow;
    }
  }

  /// إرسال رسالة
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    MessageType type = MessageType.text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    String? audioUrl,
    int? audioDuration,
    Map<String, dynamic>? location,
  }) async {
    try {
      final messageData = {
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type.toString().split('.').last,
        'readBy': [senderId],
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (audioDuration != null) 'audioDuration': audioDuration,
        if (location != null) 'location': location,
        'isDeleted': false,
      };

      // إضافة الرسالة إلى المجموعة الفرعية
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // الحصول على معلومات المحادثة لتحديث العداد
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data();
      final users = List<String>.from(chatData?['users'] ?? []);
      final otherUserId = users.firstWhere(
        (id) => id != senderId,
        orElse: () => '',
      );

      // تحديث آخر رسالة في المحادثة
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'unreadCount.$otherUserId': FieldValue.increment(1),
        'deletedBy.$otherUserId':
            FieldValue.delete(), // إلغاء الحذف للمستخدم الآخر
      });

      print('✅ تم إرسال الرسالة بنجاح');
    } catch (e) {
      print('❌ خطأ في إرسال الرسالة: $e');
      rethrow;
    }
  }

  /// تمييز الرسائل كمقروءة
  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
  }) async {
    try {
      // جلب جميع الرسائل التي لم يقرأها المستخدم بعد
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where(
            'readBy',
            whereNotIn: [
              [userId],
            ],
          )
          .get();

      if (messagesSnapshot.docs.isEmpty) {
        print('✅ لا توجد رسائل جديدة لتمييزها كمقروءة');
        return;
      }

      final batch = _firestore.batch();
      int updatedCount = 0;

      for (var doc in messagesSnapshot.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(userId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([userId]),
          });
          updatedCount++;
        }
      }

      // إعادة تعيين عداد الرسائل غير المقروءة
      batch.update(_firestore.collection('chats').doc(chatId), {
        'unreadCount.$userId': 0,
      });

      await batch.commit();
      print('✅ تم تمييز $updatedCount رسالة كمقروءة');
    } catch (e) {
      print('❌ خطأ في تمييز الرسائل كمقروءة: $e');
    }
  }

  /// حذف رسالة
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    bool forEveryone = false,
  }) async {
    try {
      if (forEveryone) {
        // حذف نهائي
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .delete();
      } else {
        // وضع علامة محذوف
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({'isDeleted': true, 'text': 'تم حذف هذه الرسالة'});
      }
      print('✅ تم حذف الرسالة');
    } catch (e) {
      print('❌ خطأ في حذف الرسالة: $e');
    }
  }

  /// حذف المحادثة
  Future<void> deleteChat({
    required String chatId,
    required String userId,
    bool forBoth = false,
  }) async {
    try {
      if (forBoth) {
        // حذف نهائي
        await _firestore.collection('chats').doc(chatId).delete();
      } else {
        // إخفاء من المستخدم فقط
        await _firestore.collection('chats').doc(chatId).update({
          'deletedBy.$userId': true,
        });
      }
      print('✅ تم حذف المحادثة');
    } catch (e) {
      print('❌ خطأ في حذف المحادثة: $e');
    }
  }

  /// حظر مستخدم
  Future<void> blockUser({
    required String chatId,
    required String userId,
    required bool block,
  }) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'blockedBy.$userId': block,
      });
      print(block ? '✅ تم حظر المستخدم' : '✅ تم إلغاء الحظر');
    } catch (e) {
      print('❌ خطأ في حظر/إلغاء حظر المستخدم: $e');
    }
  }

  /// جلب المحادثات (Stream)
  Stream<List<ChatRoom>> getChatRooms(String userId) {
    return _firestore
        .collection('chats')
        .where('users', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          // الفلترة وإخفاء المحادثات المحذوفة
          final chatRooms = snapshot.docs
              .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
              .where((chat) {
                // إخفاء المحادثات المحذوفة
                return chat.deletedBy == null ||
                    chat.deletedBy![userId] != true;
              })
              .toList();

          // الترتيب من جانب العميل بدلاً من Firestore
          chatRooms.sort((a, b) {
            if (a.lastTimestamp == null && b.lastTimestamp == null) return 0;
            if (a.lastTimestamp == null) return 1;
            if (b.lastTimestamp == null) return -1;
            return b.lastTimestamp!.compareTo(a.lastTimestamp!);
          });

          return chatRooms;
        });
  }

  /// جلب الرسائل (Stream)
  Stream<List<Message>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id))
              .where((msg) => msg.isDeleted != true)
              .toList();
        });
  }

  /// جلب معلومات مستخدم
  Future<ChatUser?> getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return ChatUser.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('❌ خطأ في جلب معلومات المستخدم: $e');
      return null;
    }
  }

  /// البحث عن مستخدمين
  Future<List<ChatUser>> searchUsers({
    required String query,
    String? role,
  }) async {
    try {
      Query<Map<String, dynamic>> queryRef = _firestore.collection('users');

      if (role != null) {
        queryRef = queryRef.where('accountType', isEqualTo: role);
      }

      final snapshot = await queryRef.get();

      return snapshot.docs
          .map((doc) => ChatUser.fromMap(doc.data(), doc.id))
          .where(
            (user) =>
                user.name.toLowerCase().contains(query.toLowerCase()) ||
                user.phone.contains(query),
          )
          .toList();
    } catch (e) {
      print('❌ خطأ في البحث عن المستخدمين: $e');
      return [];
    }
  }

  /// الحصول على عدد الرسائل غير المقروءة
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('chats')
        .where('users', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
            if (unreadCount != null && unreadCount[userId] != null) {
              total += (unreadCount[userId] as num).toInt();
            }
          }
          return total;
        });
  }

  /// Helper: الحصول على معرف المستخدم الآخر من بيانات المحادثة
  String getOtherUserId(Map<String, dynamic> chatData, String currentUserId) {
    final users = List<String>.from(chatData['users'] ?? []);
    return users.firstWhere((id) => id != currentUserId, orElse: () => '');
  }

  /// Helper: الحصول على معلومات المستخدم الآخر من بيانات المحادثة
  Map<String, dynamic> getOtherUserInfo(
    Map<String, dynamic> chatData,
    String currentUserId,
  ) {
    final otherUserId = getOtherUserId(chatData, currentUserId);
    final userInfo = chatData['userInfo'] as Map<String, dynamic>?;

    print('🔍 userInfo من المحادثة: $userInfo');
    print('🔍 otherUserId: $otherUserId');

    if (userInfo != null && userInfo.containsKey(otherUserId)) {
      final info = Map<String, dynamic>.from(userInfo[otherUserId]);
      print('✅ تم العثور على معلومات المستخدم: $info');
      return info;
    }

    print('⚠️ لم يتم العثور على معلومات المستخدم في userInfo');
    return {'name': 'مستخدم', 'imageUrl': null, 'phone': otherUserId};
  }
}
