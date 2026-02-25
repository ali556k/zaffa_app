import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import '../screens/chat_room_screen.dart';

/// دوال مساعدة لنظام المحادثات
class ChatHelper {
  static final ChatService _chatService = ChatService();

  /// بدء محادثة مع مستخدم (مثال: مزود خدمة)
  static Future<void> startChatWithUser({
    required BuildContext context,
    required String otherUserId,
    required String otherUserName,
    String? otherUserImage,
    String? otherUserRole,
    String? serviceName, // اسم الخدمة (للعرض بدلاً من اسم المزود)
  }) async {
    try {
      // الحصول على معلومات المستخدم الحالي
      final prefs = await SharedPreferences.getInstance();
      final currentUserId =
          prefs.getString('currentUserId') ?? prefs.getString('user_phone');

      // التحقق مما إذا كان المستخدم ضيفاً
      if (currentUserId == 'guest') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('المحادثات غير متاحة للضيوف. يرجى إنشاء حساب أولاً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
        );
        return;
      }

      // تحديد دور المستخدم الحالي
      final accountType = prefs.getString('accountType');
      String currentUserRole = 'customer';
      if (accountType == 'provider') {
        currentUserRole = 'provider';
      } else if (currentUserId == '07721874360') {
        currentUserRole = 'owner';
      }

      // معلومات المستخدم الحالي
      final currentUserInfo = {
        'name':
            prefs.getString('user_name') ??
            prefs.getString('providerName') ??
            'مستخدم',
        'imageUrl': prefs.getString('profileImage'),
        'role': currentUserRole,
      };

      // معلومات المستخدم الآخر
      final otherUserInfo = {
        'name': otherUserName,
        'imageUrl': otherUserImage,
        'role': otherUserRole ?? 'customer',
        if (serviceName != null) 'serviceName': serviceName, // حفظ اسم الخدمة
      };

      // تحديد الاسم المعروض حسب دور المستخدم الحالي
      String displayName = otherUserName;

      // إذا كان المستخدم الآخر هو المالك، يظهر دائماً باسم "الدعم الفني"
      if (otherUserId == '07721874360') {
        displayName = 'الدعم الفني';
      } else if (otherUserRole == 'provider' && serviceName != null) {
        // إذا كان المستخدم الآخر مزود خدمة ويوجد اسم خدمة
        // الزبون والمالك يرون اسم الخدمة
        if (currentUserRole == 'customer' || currentUserRole == 'owner') {
          displayName = serviceName;
        }
      }

      // إنشاء أو الحصول على غرفة المحادثة
      final chatId = await _chatService.getOrCreateChatRoom(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
        currentUserInfo: currentUserInfo,
        otherUserInfo: otherUserInfo,
      );

      // فتح شاشة المحادثة
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            chatId: chatId,
            otherUserId: otherUserId,
            otherUserName: displayName, // استخدام الاسم المعروض
            otherUserImage: otherUserImage,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في فتح المحادثة: $e')));
    }
  }

  /// بدء محادثة مع المالك
  static Future<void> startChatWithOwner(BuildContext context) async {
    await startChatWithUser(
      context: context,
      otherUserId: '07721874360', // رقم هاتف المالك الصحيح
      otherUserName: 'الدعم الفني',
      otherUserImage: null,
      otherUserRole: 'owner',
    );
  }

  /// زر المحادثة السريع (Widget)
  static Widget buildChatButton({
    required BuildContext context,
    required String otherUserId,
    required String otherUserName,
    String? otherUserImage,
    bool isFloating = false,
  }) {
    if (isFloating) {
      return FloatingActionButton(
        onPressed: () => startChatWithUser(
          context: context,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserImage: otherUserImage,
        ),
        backgroundColor: const Color(0xFF2B0606),
        child: const Icon(Icons.chat, color: Colors.white),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => startChatWithUser(
        context: context,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserImage: otherUserImage,
      ),
      icon: const Icon(Icons.chat, color: Colors.white),
      label: const Text('محادثة', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2B0606),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// عداد الرسائل غير المقروءة (Badge)
  static Widget buildUnreadBadge() {
    return FutureBuilder<String?>(
      future: SharedPreferences.getInstance().then(
        (prefs) =>
            prefs.getString('currentUserId') ?? prefs.getString('user_phone'),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        return StreamBuilder<int>(
          stream: _chatService.getUnreadCount(snapshot.data!),
          builder: (context, unreadSnapshot) {
            final unreadCount = unreadSnapshot.data ?? 0;
            if (unreadCount == 0) return const SizedBox.shrink();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        );
      },
    );
  }
}
