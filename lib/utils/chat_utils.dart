class ChatUtils {
  /// إنشاء معرف محادثة فريد بين مستخدمين
  /// يضمن أن نفس المعرف يتم إنشاؤه بغض النظر عن ترتيب المستخدمين
  static String createChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'chat-${sortedIds[0]}-${sortedIds[1]}';
  }

  /// إنشاء معرف محادثة الدعم الفني مع المالك
  static String createSupportChatId(String userPhone) {
    return 'support-$userPhone-07721874360';
  }

  /// تحقق من صحة معرف المحادثة
  static bool isValidChatId(String chatId) {
    return chatId.contains('-') && chatId.length > 5;
  }

  /// استخراج معرفات المستخدمين من معرف المحادثة
  static List<String> extractUserIds(String chatId) {
    if (chatId.startsWith('chat-')) {
      final parts = chatId.substring(5).split('-');
      if (parts.length >= 2) {
        return [parts[0], parts.sublist(1).join('-')];
      }
    } else if (chatId.startsWith('support-')) {
      final parts = chatId.substring(8).split('-');
      if (parts.length >= 2) {
        return [parts[0], parts.sublist(1).join('-')];
      }
    }
    return [];
  }
}
