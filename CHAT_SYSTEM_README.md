# 💬 نظام المحادثات الفوري - تطبيق زفة

## 📋 نظرة عامة

نظام محادثات احترافي فوري (Real-time Chat System) مبني على Flutter و Firebase Firestore.

## 🏗️ البنية

```
lib/
├── models/
│   └── chat_models.dart          # نماذج البيانات (ChatUser, ChatRoom, Message)
├── services/
│   ├── chat_service.dart         # خدمة إدارة المحادثات
│   └── storage_service.dart      # خدمة تخزين الملفات
├── screens/
│   ├── chats_list_screen.dart    # شاشة قائمة المحادثات
│   └── chat_room_screen.dart     # شاشة غرفة المحادثة
└── widgets/
    └── message_bubble.dart        # فقاعة الرسالة
```

## 🎯 الميزات المنفذة

### ✅ الميزات الأساسية
- [x] محادثات فورية (Real-time) باستخدام StreamBuilder
- [x] دعم المحادثات بين:
  - الزبون ↔ مزود الخدمة
  - الزبون ↔ المالك
  - مزود الخدمة ↔ المالك
- [x] واجهة مستخدم احترافية (شبيهة بواتساب)
- [x] فقاعات رسائل ملونة حسب المرسل
- [x] عرض صورة المرسل ووقت الإرسال

### ✅ ميزات متقدمة
- [x] تمييز الرسائل المقروءة (✓✓) وغير المقروءة (✓)
- [x] عداد الرسائل غير المقروءة
- [x] فرز المحادثات حسب آخر تفاعل
- [x] دعم إرسال الصور
- [x] دعم إرسال الموقع
- [x] حذف الرسائل
- [x] حذف المحادثات
- [x] إخفاء المحادثة من طرف واحد

### 🔜 ميزات قابلة للإضافة مستقبلاً
- [ ] الرسائل الصوتية (البنية جاهزة)
- [ ] إرسال الملفات
- [ ] إشعارات فورية (FCM)
- [ ] حظر المستخدمين
- [ ] الرد على رسالة محددة
- [ ] إعادة توجيه الرسائل
- [ ] البحث في الرسائل

## 🗂️ هيكل قاعدة البيانات (Firestore)

### Collection: `chats`
```json
{
  "chatId": {
    "users": ["userId1", "userId2"],
    "userInfo": {
      "userId1": {"name": "أحمد", "imageUrl": "..."},
      "userId2": {"name": "محمد", "imageUrl": "..."}
    },
    "lastMessage": "آخر رسالة...",
    "lastTimestamp": Timestamp,
    "lastSenderId": "userId1",
    "unreadCount": {
      "userId1": 0,
      "userId2": 3
    },
    "deletedBy": {
      "userId1": false
    },
    "blockedBy": {
      "userId1": false
    },
    "createdAt": Timestamp
  }
}
```

### SubCollection: `chats/{chatId}/messages`
```json
{
  "messageId": {
    "senderId": "userId1",
    "text": "نص الرسالة",
    "timestamp": Timestamp,
    "type": "text|image|location|audio|file",
    "readBy": ["userId1", "userId2"],
    "imageUrl": "...",
    "location": {"latitude": 0.0, "longitude": 0.0},
    "audioUrl": "...",
    "audioDuration": 10,
    "fileUrl": "...",
    "fileName": "...",
    "isDeleted": false
  }
}
```

## 🚀 كيفية الاستخدام

### 1. إضافة زر المحادثات في التطبيق

في أي شاشة تريد إضافة زر المحادثات:

```dart
import 'package:clean_app/screens/chats_list_screen.dart';

// مثال: في AppBar
AppBar(
  actions: [
    IconButton(
      icon: const Icon(Icons.chat),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatsListScreen(),
          ),
        );
      },
    ),
  ],
)
```

### 2. بدء محادثة مع مستخدم معين

```dart
import 'package:clean_app/services/chat_service.dart';
import 'package:clean_app/screens/chat_room_screen.dart';

// مثال: عند النقر على مزود خدمة
Future<void> startChat(String otherUserId, String otherUserName) async {
  final chatService = ChatService();
  
  // الحصول على معرف المستخدم الحالي
  final prefs = await SharedPreferences.getInstance();
  final currentUserId = prefs.getString('currentUserId') ?? 
                       prefs.getString('user_phone');
  
  // معلومات المستخدمين
  final currentUserInfo = {
    'name': prefs.getString('user_name') ?? 'أنا',
    'imageUrl': null,
  };
  
  final otherUserInfo = {
    'name': otherUserName,
    'imageUrl': null,
  };
  
  // إنشاء أو الحصول على غرفة المحادثة
  final chatId = await chatService.getOrCreateChatRoom(
    currentUserId: currentUserId!,
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
        otherUserName: otherUserName,
      ),
    ),
  );
}
```

### 3. إضافة زر المحادثة في صفحة تفاصيل مزود الخدمة

```dart
// في صفحة تفاصيل مزود الخدمة أو الحجز
ElevatedButton.icon(
  onPressed: () => startChat(
    providerId, // معرف مزود الخدمة
    providerName, // اسم مزود الخدمة
  ),
  icon: const Icon(Icons.chat),
  label: const Text('محادثة'),
)
```

## 🎨 تخصيص الألوان

يمكنك تغيير الألوان الرئيسية من خلال:

### في `chats_list_screen.dart`:
```dart
// لون الـ AppBar
backgroundColor: const Color(0xFF2B0606), // ماروني

// لون الزر العائم
backgroundColor: const Color(0xFF2B0606),
```

### في `chat_room_screen.dart`:
```dart
// خلفية المحادثة
backgroundColor: const Color(0xFFE5DDD5), // بيج فاتح

// لون فقاعة الرسائل
color: isMe
    ? const Color(0xFF2B0606)  // ماروني للمرسل
    : Colors.white,            // أبيض للمستقبل
```

## 🔐 الأمان

- ✅ يتم التحقق من معرف المستخدم قبل كل عملية
- ✅ لا يمكن قراءة رسائل محادثات الآخرين
- ✅ Firestore Security Rules (يجب إضافتها):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.users;
      
      match /messages/{messageId} {
        allow read, write: if request.auth != null && 
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.users;
      }
    }
  }
}
```

## 📱 الإشعارات الفورية (FCM)

لإضافة الإشعارات عند استلام رسالة جديدة:

1. في `chat_service.dart` → `sendMessage()`:

```dart
// بعد إرسال الرسالة
await _sendNotification(
  userId: otherUserId,
  title: senderName,
  body: text,
);
```

2. إنشاء دالة إرسال الإشعار:

```dart
Future<void> _sendNotification({
  required String userId,
  required String title,
  required String body,
}) async {
  // الحصول على FCM Token من users collection
  final userDoc = await _firestore.collection('users').doc(userId).get();
  final fcmToken = userDoc.data()?['fcmToken'];
  
  if (fcmToken != null) {
    // إرسال الإشعار عبر Cloud Functions
  }
}
```

## 🐛 استكشاف الأخطاء

### المحادثات لا تظهر؟
- تأكد من أن `currentUserId` محفوظ في SharedPreferences
- تحقق من أن حقل `users` في Firestore يحتوي على المعرفات الصحيحة

### الرسائل لا تُرسل؟
- تحقق من اتصال الإنترنت
- تأكد من صلاحيات Firestore
- راجع console للأخطاء

### الصور لا تُرفع؟
- تأكد من صلاحيات Firebase Storage
- تحقق من حجم الصورة (يفضل أقل من 5MB)

## 📝 ملاحظات مهمة

1. **RTL Support**: جميع الواجهات تدعم اللغة العربية من اليمين لليسار
2. **Scalability**: النظام قابل للتوسع لآلاف المحادثات
3. **Offline Support**: Firestore يدعم التخزين المؤقت تلقائياً
4. **Performance**: استخدام `limit(100)` لتحميل آخر 100 رسالة فقط

## 🎓 التطوير المستقبلي

للتوسع في النظام:
1. إضافة المكالمات الصوتية/المرئية (WebRTC)
2. تحسين البحث باستخدام Algolia
3. إضافة الترجمة الفورية
4. دعم الملصقات (Stickers)
5. الحالات (Stories) مثل واتساب

---

**تم التطوير بواسطة:** نظام محادثات زفة الاحترافي
**التاريخ:** 2025
**الإصدار:** 1.0.0
