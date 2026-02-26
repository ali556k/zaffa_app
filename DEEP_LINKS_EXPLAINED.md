# 🔗 دليل Deep Links - تطبيق زفة

## 🤔 شنو هي Deep Links؟

Deep Links هي روابط تفتح التطبيق مباشرة في صفحة معينة (مثل فتح منتج معين أو ملف شخصي).

**مثال:**
- بدل ما المستخدم يفتح التطبيق → يدور → يلاقي الخدمة
- يضغط على رابط → التطبيق يفتح مباشرة على الخدمة!

---

## 📍 وين موجودة؟

### للأندرويد:
**الملف:** [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)

**الأسطر:** 50-74

### لـ iOS:
**الملف:** [ios/Runner/Info.plist](ios/Runner/Info.plist)

**الأسطر:** 50-67

---

## 🎯 شنو الأنواع الموجودة؟

### 1️⃣ Custom Scheme (zafa://)

**مثل:**
```
zafa://item/abc123           → يفتح عنصر معين
zafa://provider/xyz789       → يفتح صفحة مزود خدمة
zafa://booking/booking_001   → يفتح صفحة حجز
zafa://app                   → يفتح الشاشة الرئيسية
```

**الاستخدام:**
- مشاركة روابط داخل التطبيق
- إشعارات تفتح صفحات محددة
- روابط من تطبيقات أخرى

---

### 2️⃣ Web URLs (https://zafaapp.com)

**مثل:**
```
https://zafaapp.com/item/abc123
https://zafaapp.com/provider/xyz789
https://zafaapp.com/booking/booking_001
```

**الاستخدام:**
- مشاركة الروابط على وسائل التواصل الاجتماعي
- إرسال روابط عبر WhatsApp
- إعلانات Google/Facebook
- SEO (محركات البحث)

---

## 🛠️ التكوين الحالي:

### Android (AndroidManifest.xml):

```xml
<!-- Deep Links - Custom Scheme (zafa://) -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    
    <data android:scheme="zafa" />
    <data android:host="item" />
    <data android:host="provider" />
    <data android:host="booking" />
    <data android:host="app" />
</intent-filter>

<!-- App Links - Web URLs (https://zafaapp.com) -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    
    <data android:scheme="https" />
    <data android:host="zafaapp.com" />
    <data android:pathPrefix="/item/" />
    <data android:pathPrefix="/provider/" />
    <data android:pathPrefix="/booking/" />
</intent-filter>
```

### iOS (Info.plist):

```xml
<!-- Deep Links Configuration -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.zafa.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>zafa</string>
        </array>
    </dict>
</array>

<!-- Universal Links (App Links) -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:zafaapp.com</string>
</array>
```

---

## ✅ هل تحتاج تعديل؟

**الجواب: لا! Deep Links جاهزة ومُعدّة بشكل صحيح ✅**

### لكن إذا أردت تعديلها:

#### 1. تغيير الدومين من zafaapp.com إلى دومين آخر:

**مثلاً تريد استخدام: `zafa-app.com`**

**في AndroidManifest.xml:**
```xml
<data android:host="zafa-app.com" />  <!-- بدل zafaapp.com -->
```

**في Info.plist:**
```xml
<string>applinks:zafa-app.com</string>  <!-- بدل zafaapp.com -->
```

#### 2. إضافة نوع Deep Link جديد:

**مثلاً تريد إضافة: `zafa://chat/ID`**

**في AndroidManifest.xml:**
```xml
<data android:host="chat" />  <!-- أضف هذا السطر -->
```

---

## 🧪 كيفية الاختبار:

### على Android:

#### باستخدام ADB:

```bash
# اختبار Custom Scheme
adb shell am start -W -a android.intent.action.VIEW -d "zafa://item/test123" com.zafa.app

# اختبار Web URL
adb shell am start -W -a android.intent.action.VIEW -d "https://zafaapp.com/item/test123" com.zafa.app
```

#### باستخدام المتصفح:
1. افتح Chrome على الهاتف
2. اكتب في شريط العنوان:
   ```
   zafa://item/test123
   ```
3. اضغط Enter
4. يفتح التطبيق (إذا كان مثبّتاً)

---

### على iOS:

#### باستخدام Safari:
1. افتح Safari
2. اكتب:
   ```
   zafa://item/test123
   ```
3. اضغط Go
4. سيفتح التطبيق

---

## ⚠️ ملاحظات مهمة:

### 1. Web URLs (Universal Links) تحتاج ملف إضافي:

لكي تعمل روابط `https://zafaapp.com` بشكل صحيح، تحتاج:

#### للأندرويد:
ملف في الموقع:
```
https://zafaapp.com/.well-known/assetlinks.json
```

**محتوى الملف:**
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.zafa.app",
    "sha256_cert_fingerprints": ["YOUR_SHA256_FINGERPRINT"]
  }
}]
```

**للحصول على SHA256:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### لـ iOS:
ملف في الموقع:
```
https://zafaapp.com/.well-known/apple-app-site-association
```

**محتوى الملف:**
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.zafa.app",
        "paths": ["/item/*", "/provider/*", "/booking/*"]
      }
    ]
  }
}
```

### 2. دومين zafaapp.com:

**حالياً:** الدومين `zafaapp.com` مستخدم في الكود ولكن:
- ⚠️ قد لا يكون مسجّلاً لك
- ⚠️ يحتاج ملفات `.well-known` (أعلاه)

**الحل البديل:**
- استخدم Custom Scheme فقط (`zafa://`) حالياً ✅
- عندما تسجّل دومين خاص، حدّث الإعدادات

---

## 💡 أمثلة عملية:

### 1. مشاركة عنصر:

```dart
// في الكود
import 'package:share_plus/share_plus.dart';

void shareItem(String itemId) {
  Share.share(
    'شوف هذه الخدمة الرائعة!\n'
    'zafa://item/$itemId',
    subject: 'خدمة من تطبيق زفة'
  );
}
```

### 2. إشعار يفتح صفحة معينة:

```dart
// عند إرسال إشعار من Firebase
{
  "notification": {
    "title": "حجز جديد!",
    "body": "لديك حجز جديد من أحمد"
  },
  "data": {
    "deep_link": "zafa://booking/booking_123",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
```

### 3. معالجة Deep Link في التطبيق:

**الملف:** `lib/main.dart`

```dart
import 'package:app_links/app_links.dart';

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _handleDeepLinks();
  }

  void _handleDeepLinks() {
    _appLinks.uriLinkStream.listen((uri) {
      // معالجة الرابط
      if (uri.host == 'item' && uri.pathSegments.isNotEmpty) {
        String itemId = uri.pathSegments[0];
        // افتح صفحة العنصر
        Navigator.pushNamed(context, '/item', arguments: itemId);
      } else if (uri.host == 'provider') {
        // افتح صفحة المزود
      } else if (uri.host == 'booking') {
        // افتح صفحة الحجز
      }
    });
  }
}
```

---

## 📊 ملخص:

| النوع | الحالة | الاستخدام |
|------|--------|-----------|
| Custom Scheme (zafa://) | ✅ جاهز | داخل التطبيق والإشعارات |
| Web URLs (https) | ⚠️ يحتاج إعداد إضافي | للمشاركة على الويب |
| Package Name | ✅ com.zafa.app | محدّث |
| معالجة الروابط في الكود | ⚠️ يحتاج تطبيق | استخدم app_links |

---

## ✅ الخلاصة:

**Deep Links جاهزة ولا تحتاج تعديل حالياً! ✅**

- `zafa://` يعمل بدون إعدادات إضافية
- `https://zafaapp.com` يحتاج دومين وملفات `.well-known`
- Package Name محدّث إلى `com.zafa.app`
- الكود جاهز - تحتاج فقط معالجة الروابط في `main.dart`

---

## 📚 مصادر إضافية:

- [توثيق Flutter App Links](https://pub.dev/packages/app_links)
- [Android Deep Links Guide](https://developer.android.com/training/app-links)
- [iOS Universal Links Guide](https://developer.apple.com/ios/universal-links/)

---

**ملاحظة:** إذا احتجت مساعدة في معالجة Deep Links في الكود، اسألني!
