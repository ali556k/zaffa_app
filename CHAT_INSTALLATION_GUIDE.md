# 🚀 دليل التثبيت والتشغيل السريع - نظام المحادثات

## ✅ الخطوة 1: التحقق من المكتبات المطلوبة

جميع المكتبات المطلوبة موجودة بالفعل في `pubspec.yaml`:

```yaml
dependencies:
  cloud_firestore: ^5.4.4
  firebase_storage: ^12.3.4
  image_picker: ^1.1.1
  shared_preferences: ^2.5.3
  geolocator: ^10.1.0
  intl: 0.20.2
  url_launcher: ^6.1.0
```

لا حاجة لإضافة أي مكتبة جديدة!

---

## ✅ الخطوة 2: إعداد Firestore Security Rules

أضف القواعد التالية في Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // قواعد المحادثات
    match /chats/{chatId} {
      // السماح بالقراءة والكتابة للمستخدمين المشاركين في المحادثة فقط
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.users;
      
      // قواعد الرسائل داخل المحادثة
      match /messages/{messageId} {
        allow read, write: if request.auth != null && 
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.users;
      }
    }
    
    // قواعد المستخدمين (للقراءة فقط)
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## ✅ الخطوة 3: إعداد Firebase Storage Rules

أضف القواعد التالية في Firebase Console → Storage → Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /chat_images/{chatId}/{senderId}/{fileName} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == senderId;
    }
    
    match /chat_files/{chatId}/{senderId}/{fileName} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == senderId;
    }
    
    match /chat_audio/{chatId}/{senderId}/{fileName} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == senderId;
    }
  }
}
```

---

## ✅ الخطوة 4: تشغيل التطبيق

```bash
# تحديث المكتبات
flutter pub get

# تشغيل التطبيق
flutter run
```

---

## 🎯 الخطوة 5: دمج المحادثات في التطبيق

### أ) إضافة زر المحادثات في الصفحة الرئيسية للزبون

في `lib/screens/main_navigation_screen.dart`:

```dart
import 'package:clean_app/screens/chats_list_screen.dart';

// في AppBar أو BottomNavigationBar
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

### ب) إضافة زر محادثة مع مزود الخدمة

في `lib/screens/item_details_screen.dart` أو أي صفحة تفاصيل:

```dart
import 'package:clean_app/utils/chat_helper.dart';

// إضافة زر المحادثة
ChatHelper.buildChatButton(
  context: context,
  otherUserId: providerId,    // معرف مزود الخدمة
  otherUserName: providerName, // اسم مزود الخدمة
  otherUserImage: providerImage, // صورة مزود الخدمة (اختياري)
)
```

### ج) إضافة المحادثات في Bottom Navigation

في `lib/screens/provider_main_professional.dart`:

```dart
import 'package:clean_app/screens/chats_list_screen.dart';

// إضافة المحادثات كتبويبة جديدة
final List<Widget> _screens = [
  _buildProfessionalHomeScreen(),
  _buildBookingsScreen(),
  const ChatsListScreen(), // ✅ جديد
  _buildProfessionalAccountScreen(),
];

// تحديث BottomNavigationBar
BottomNavigationBar(
  items: const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
    BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'الحجوزات'),
    BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'المحادثات'), // ✅ جديد
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'الحساب'),
  ],
)
```

---

## 🎨 الخطوة 6: التخصيص (اختياري)

### تغيير الألوان الرئيسية:

في `lib/screens/chats_list_screen.dart`:
```dart
backgroundColor: const Color(0xFF2B0606), // لون ماروني
```

في `lib/widgets/message_bubble.dart`:
```dart
color: isMe ? const Color(0xFF2B0606) : Colors.white,
```

### تغيير رقم هاتف المالك:

في `lib/utils/chat_helper.dart`:
```dart
static Future<void> startChatWithOwner(BuildContext context) async {
  await startChatWithUser(
    context: context,
    otherUserId: '0772187444', // ← غير هذا الرقم
    otherUserName: 'المالك',
  );
}
```

---

## 📱 الخطوة 7: اختبار النظام

### 1. تسجيل دخول كزبون:
- افتح التطبيق وسجل دخول كزبون
- افتح صفحة مزود خدمة
- اضغط على زر "محادثة"

### 2. تسجيل دخول كمزود خدمة:
- افتح التطبيق وسجل دخول كمزود خدمة
- اذهب إلى تبويب "المحادثات"
- شاهد المحادثات الواردة

### 3. اختبار الميزات:
- ✅ إرسال رسالة نصية
- ✅ إرسال صورة
- ✅ إرسال موقع
- ✅ حذف رسالة
- ✅ حذف محادثة
- ✅ علامات القراءة (✓✓)

---

## 🐛 حل المشاكل الشائعة

### المشكلة: "المحادثات لا تظهر"
**الحل:**
```dart
// تأكد من أن currentUserId محفوظ في SharedPreferences
final prefs = await SharedPreferences.getInstance();
print('Current User ID: ${prefs.getString('currentUserId')}');
```

### المشكلة: "لا يمكن إرسال الرسائل"
**الحل:**
- تحقق من Firestore Security Rules
- تأكد من اتصال الإنترنت
- راجع الـ console للأخطاء

### المشكلة: "الصور لا تُرفع"
**الحل:**
- تحقق من Firebase Storage Rules
- تأكد من صلاحيات الكاميرا والمعرض في `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### المشكلة: "لا يمكن إرسال الموقع"
**الحل:**
- تأكد من صلاحيات الموقع في `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

---

## 📊 الإحصائيات والتقارير

### عدد المحادثات النشطة:
```dart
StreamBuilder<List<ChatRoom>>(
  stream: chatService.getChatRooms(userId),
  builder: (context, snapshot) {
    final count = snapshot.data?.length ?? 0;
    return Text('عدد المحادثات: $count');
  },
)
```

### عدد الرسائل غير المقروءة:
```dart
StreamBuilder<int>(
  stream: chatService.getUnreadCount(userId),
  builder: (context, snapshot) {
    final unread = snapshot.data ?? 0;
    return Badge(label: Text('$unread'));
  },
)
```

---

## 🎓 الميزات المتقدمة (للمستقبل)

### 1. الإشعارات الفورية (FCM):
```dart
// في chat_service.dart → sendMessage()
await _sendPushNotification(
  userId: otherUserId,
  title: senderName,
  body: message,
);
```

### 2. الرسائل الصوتية:
```dart
// استخدم package: record
await _recordAudio();
final audioUrl = await storageService.uploadAudio(audioFile);
await chatService.sendMessage(
  type: MessageType.audio,
  audioUrl: audioUrl,
);
```

### 3. المكالمات الصوتية/المرئية:
```dart
// استخدم package: agora_rtc_engine
// أو WebRTC
```

---

## ✨ النتيجة النهائية

الآن لديك نظام محادثات احترافي يتضمن:

- ✅ محادثات فورية (Real-time)
- ✅ دعم الصور والمواقع
- ✅ علامات القراءة
- ✅ عداد الرسائل غير المقروءة
- ✅ واجهة مستخدم احترافية
- ✅ أمان عالي
- ✅ قابل للتوسع

**استمتع بنظام المحادثات! 🎉**

---

**للدعم والأسئلة:**
- راجع ملف `CHAT_SYSTEM_README.md`
- راجع أمثلة الدمج في `lib/examples/chat_integration_examples.dart`
- تحقق من الـ console للأخطاء والرسائل التوضيحية
