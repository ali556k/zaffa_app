# إعداد Deep Links لتطبيق زفة
## Deep Links Configuration Guide

### 📋 نظرة عامة

تم تحديث `ShareService` ليتضمن **Deep Links** تفتح التطبيق مباشرة عند النقر على الروابط المشاركة.

---

## 🔗 أنواع الروابط المدعومة

### 1. رابط العنصر (Item)
```
Deep Link:  zafa://item/{itemId}
Web Link:   https://zafaapp.com/item/{itemId}
```

### 2. رابط المزود (Provider)
```
Deep Link:  zafa://provider/{providerId}
Web Link:   https://zafaapp.com/provider/{providerId}
```

### 3. رابط الحجز (Booking)
```
Deep Link:  zafa://booking/{bookingId}
Web Link:   https://zafaapp.com/booking/{bookingId}
```

### 4. رابط التطبيق (App)
```
Play Store: https://play.google.com/store/apps/details?id=com.zafa.app
App Store:  https://apps.apple.com/app/zafa/id123456789
Website:    https://zafaapp.com
```

---

## 📱 إعداد Deep Links في Android

### 1. تحديث `android/app/src/main/AndroidManifest.xml`

أضف التالي داخل `<activity>` الرئيسية:

```xml
<activity
    android:name=".MainActivity"
    ...>
    
    <!-- Existing intent filters -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    
    <!-- Deep Link Scheme (zafa://) -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <data
            android:scheme="zafa"
            android:host="item" />
        <data
            android:scheme="zafa"
            android:host="provider" />
        <data
            android:scheme="zafa"
            android:host="booking" />
    </intent-filter>
    
    <!-- App Links (https://zafaapp.com) -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <data
            android:scheme="https"
            android:host="zafaapp.com"
            android:pathPrefix="/item" />
        <data
            android:scheme="https"
            android:host="zafaapp.com"
            android:pathPrefix="/provider" />
        <data
            android:scheme="https"
            android:host="zafaapp.com"
            android:pathPrefix="/booking" />
    </intent-filter>
    
</activity>
```

### 2. إنشاء ملف Digital Asset Links (للروابط العامة)

أنشئ ملف `.well-known/assetlinks.json` على سيرفرك:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.zafa.app",
    "sha256_cert_fingerprints": [
      "YOUR_SHA256_FINGERPRINT_HERE"
    ]
  }
}]
```

**الحصول على SHA256 Fingerprint**:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

---

## 🍎 إعداد Deep Links في iOS

### 1. تحديث `ios/Runner/Info.plist`

أضف التالي:

```xml
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

### 2. إنشاء ملف Apple App Site Association

أنشئ ملف `.well-known/apple-app-site-association` على سيرفرك:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.zafa.app",
        "paths": [
          "/item/*",
          "/provider/*",
          "/booking/*"
        ]
      }
    ]
  }
}
```

**ملاحظة**: استبدل `TEAM_ID` بمعرف فريق Apple Developer.

---

## 🔧 إعداد Flutter للتعامل مع Deep Links

### 1. إضافة Package للتعامل مع الروابط

أضف إلى `pubspec.yaml`:

```yaml
dependencies:
  uni_links: ^0.5.1
  # أو البديل الحديث:
  app_links: ^3.5.0
```

### 2. إنشاء Deep Link Handler

أنشئ ملف `lib/utils/deep_link_handler.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  final _appLinks = AppLinks();
  
  /// تهيئة معالج الروابط العميقة
  Future<void> initialize(BuildContext context) async {
    // التعامل مع الرابط الذي فتح التطبيق
    final initialLink = await _appLinks.getInitialAppLink();
    if (initialLink != null) {
      _handleDeepLink(context, initialLink);
    }

    // الاستماع للروابط أثناء تشغيل التطبيق
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(context, uri);
    });
  }

  /// معالجة الرابط العميق
  void _handleDeepLink(BuildContext context, Uri uri) {
    print('📱 Deep Link received: $uri');
    
    // مسار الرابط
    final path = uri.path;
    final segments = uri.pathSegments;

    if (segments.isEmpty) return;

    // التعامل حسب نوع الرابط
    switch (segments[0]) {
      case 'item':
        if (segments.length >= 2) {
          final itemId = segments[1];
          _navigateToItem(context, itemId);
        }
        break;

      case 'provider':
        if (segments.length >= 2) {
          final providerId = segments[1];
          _navigateToProvider(context, providerId);
        }
        break;

      case 'booking':
        if (segments.length >= 2) {
          final bookingId = segments[1];
          _navigateToBooking(context, bookingId);
        }
        break;

      default:
        print('⚠️ Unknown deep link path: $path');
    }
  }

  /// الانتقال إلى شاشة العنصر
  void _navigateToItem(BuildContext context, String itemId) {
    // TODO: استبدل بالكود الفعلي للانتقال
    print('🔗 Navigate to item: $itemId');
    
    // مثال:
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => ItemDetailsScreen(itemId: itemId),
    //   ),
    // );
  }

  /// الانتقال إلى شاشة المزود
  void _navigateToProvider(BuildContext context, String providerId) {
    print('🔗 Navigate to provider: $providerId');
    
    // TODO: أضف كود الانتقال لشاشة المزود
  }

  /// الانتقال إلى شاشة الحجز
  void _navigateToBooking(BuildContext context, String bookingId) {
    print('🔗 Navigate to booking: $bookingId');
    
    // TODO: أضف كود الانتقال لشاشة الحجز
  }
}
```

### 3. تهيئة Deep Link Handler في التطبيق

في `lib/main.dart`:

```dart
import 'utils/deep_link_handler.dart';

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // انتظر حتى يكتمل بناء السياق
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkHandler().initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... باقي الكود
    );
  }
}
```

---

## 🧪 اختبار Deep Links

### اختبار Android

#### 1. اختبار Deep Link Scheme (zafa://)
```bash
# اختبار رابط عنصر
adb shell am start -W -a android.intent.action.VIEW -d "zafa://item/abc123" com.zafa.app

# اختبار رابط مزود
adb shell am start -W -a android.intent.action.VIEW -d "zafa://provider/provider123" com.zafa.app

# اختبار رابط حجز
adb shell am start -W -a android.intent.action.VIEW -d "zafa://booking/booking123" com.zafa.app
```

#### 2. اختبار App Links (https://)
```bash
# اختبار رابط عنصر
adb shell am start -W -a android.intent.action.VIEW -d "https://zafaapp.com/item/abc123" com.zafa.app

# اختبار رابط مزود
adb shell am start -W -a android.intent.action.VIEW -d "https://zafaapp.com/provider/provider123" com.zafa.app
```

### اختبار iOS

#### استخدام Simulator
```bash
# اختبار Deep Link
xcrun simctl openurl booted "zafa://item/abc123"

# اختبار Universal Link
xcrun simctl openurl booted "https://zafaapp.com/item/abc123"
```

#### استخدام Safari على الجهاز
1. افتح Safari
2. اكتب الرابط في شريط العنوان: `zafa://item/abc123`
3. اضغط Enter
4. يجب أن يفتح التطبيق

---

## 📝 ملاحظات مهمة

### 1. تحديث الروابط في ShareService

في `lib/services/share_service.dart`، استبدل:

```dart
static const String _appBaseUrl = 'https://zafaapp.com'; // ضع الدومين الفعلي
```

### 2. تحديث روابط المتاجر

```dart
const playStoreLink = 'https://play.google.com/store/apps/details?id=com.zafa.app';
const appStoreLink = 'https://apps.apple.com/app/zafa/id123456789';
```

### 3. Package Name و Bundle ID

تأكد من تطابق:
- Android: `com.zafa.app` في `android/app/build.gradle`
- iOS: `com.zafa.app` في Xcode

### 4. تفعيل App Links Verification

**Android**:
```bash
# التحقق من صحة assetlinks.json
https://developers.google.com/digital-asset-links/tools/generator
```

**iOS**:
```bash
# التحقق من صحة apple-app-site-association
https://branch.io/resources/aasa-validator/
```

---

## 🔄 مثال على استخدام المشاركة

### مشاركة عنصر مع Deep Link

```dart
await ShareService().shareItem(
  itemId: 'abc123',
  itemName: 'قاعة الأحلام',
  providerName: 'قاعات الفخامة',
  price: '5000000',
  description: 'قاعة فخمة تتسع لـ 500 شخص',
);
```

**الرسالة المشاركة ستحتوي على**:
```
🎉 اكتشف خدمة رائعة في تطبيق زفة!

📌 قاعة الأحلام
👤 من: قاعات الفخامة
السعر: 5000000 د.ع

قاعة فخمة تتسع لـ 500 شخص

🔗 افتح في التطبيق:
zafa://item/abc123

أو عبر المتصفح:
https://zafaapp.com/item/abc123

حمّل تطبيق زفة الآن واستمتع بأفضل خدمات الأعراس!
```

عند النقر على `zafa://item/abc123`:
- **إذا كان التطبيق مثبتاً**: يفتح التطبيق مباشرة ويعرض تفاصيل العنصر
- **إذا لم يكن مثبتاً**: على Android يوجه للمتجر، على iOS يفتح الرابط في المتصفح

---

## ✅ قائمة التحقق النهائية

- [ ] تحديث `android/app/src/main/AndroidManifest.xml`
- [ ] إنشاء `.well-known/assetlinks.json` على السيرفر
- [ ] تحديث `ios/Runner/Info.plist`
- [ ] إنشاء `.well-known/apple-app-site-association` على السيرفر
- [ ] إضافة package `app_links` إلى `pubspec.yaml`
- [ ] إنشاء `lib/utils/deep_link_handler.dart`
- [ ] تهيئة DeepLinkHandler في `main.dart`
- [ ] تحديث الروابط في `ShareService`
- [ ] اختبار Deep Links على Android
- [ ] اختبار Deep Links على iOS
- [ ] نشر ملفات `.well-known` على السيرفر
- [ ] التحقق من App Links Verification

---

## 🆘 استكشاف الأخطاء

### المشكلة: Deep Links لا تعمل على Android

**الحلول**:
1. تأكد من صحة package name في `AndroidManifest.xml`
2. تحقق من ملف `assetlinks.json` متاح على: `https://yourdomain.com/.well-known/assetlinks.json`
3. استخدم أداة Google للتحقق: [Digital Asset Links Tool](https://developers.google.com/digital-asset-links/tools/generator)
4. امسح cache التطبيق وأعد التثبيت

### المشكلة: Deep Links لا تعمل على iOS

**الحلول**:
1. تأكد من Bundle ID صحيح
2. تحقق من `apple-app-site-association` متاح بدون امتداد `.json`
3. تأكد من Team ID صحيح في Associated Domains
4. أعد تثبيت التطبيق بعد التغييرات

### المشكلة: الروابط تفتح المتصفح بدلاً من التطبيق

**السبب**: App Links Verification فاشل

**الحل**:
1. تحقق من ملفات `.well-known` متاحة عبر HTTPS
2. انتظر حتى 24 ساعة لتحديث Google/Apple servers
3. استخدم Deep Link Scheme (`zafa://`) للاختبار الفوري

---

## 📚 مراجع إضافية

- [Flutter Deep Linking Guide](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [Android App Links](https://developer.android.com/training/app-links)
- [iOS Universal Links](https://developer.apple.com/ios/universal-links/)
- [app_links Package](https://pub.dev/packages/app_links)

---

**تاريخ التحديث**: 2025-10-27  
**الإصدار**: 1.0.0
