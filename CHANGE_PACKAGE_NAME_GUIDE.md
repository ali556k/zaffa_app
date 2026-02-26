# 🔧 دليل تغيير Package Name

## ⚠️ مهم جداً: يجب تغيير Package Name من `com.example.clean_app`

Google Play يرفض التطبيقات التي تستخدم `com.example` في Package Name!

---

## 📝 الخطوات المطلوبة:

### 1. اختر Package Name جديد
**الصيغة:** `com.yourcompany.appname`

**أمثلة:**
- `com.zafa.app`
- `com.zafaapp.wedding`
- `com.iq.zafa`

⚠️ **ملاحظة:** Package Name يجب أن يكون فريداً على Google Play و App Store!

---

### 2. تغيير Package Name في Android

#### **الطريقة الأولى: يدوياً**

##### أ) تعديل `android/app/build.gradle.kts`:

```kotlin
android {
    namespace = "com.zafa.app"  // غيّر هنا
    compileSdk = 34
    
    defaultConfig {
        applicationId = "com.zafa.app"  // غيّر هنا
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }
}
```

##### ب) تعديل `android/app/src/main/AndroidManifest.xml`:

لا يحتاج تعديل - سيستخدم القيمة من `build.gradle` تلقائياً.

##### ج) تعديل مجلد الكود (اختياري):

```bash
# المسار الحالي
android/app/src/main/kotlin/com/example/clean_app/

# غيّره إلى
android/app/src/main/kotlin/com/zafa/app/
```

ثم عدّل في `MainActivity.kt`:
```kotlin
package com.zafa.app  // غيّر هنا

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
```

---

#### **الطريقة الثانية: باستخدام أداة (أسهل)**

```bash
# ثبّت الأداة
flutter pub add change_app_package_name --dev

# نفّذ التغيير
flutter pub run change_app_package_name:main com.zafa.app
```

---

### 3. تغيير Package Name في iOS

#### تعديل `ios/Runner/Info.plist`:

ابحث عن:
```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
```

#### تعديل في Xcode:

1. افتح المشروع:
```bash
open ios/Runner.xcworkspace
```

2. اذهب إلى:
   - **Runner** → **General**
   - **Bundle Identifier** → غيّره إلى `com.zafa.app`

3. اذهب إلى:
   - **Signing & Capabilities**
   - تأكد من تطابق Bundle Identifier

---

### 4. تحديث ملفات Firebase (إذا كنت تستخدمها)

#### لـ Android:
1. اذهب إلى [Firebase Console](https://console.firebase.google.com)
2. اختر المشروع
3. **Project Settings** → **General**
4. تحت **Your apps** → **Android app**
5. أضف تطبيق Android جديد بالـ Package Name الجديد
6. حمّل ملف `google-services.json` جديد
7. ضعه في `android/app/`

#### لـ iOS:
1. نفس الخطوات لكن اختر **iOS app**
2. حمّل ملف `GoogleService-Info.plist` جديد
3. ضعه في `ios/Runner/`

---

### 5. تنظيف المشروع

```bash
# احذف ملفات الـ build القديمة
flutter clean

# احصل على الحزم مجدداً
flutter pub get

# أعد بناء المشروع
flutter build apk --release
# أو
flutter build appbundle --release
```

---

### 6. التحقق من التغييرات

#### للتحقق من Android:
```bash
flutter build apk --release
# ثم فحص الملف المُنتج
```

#### للتحقق من iOS:
```bash
flutter build ios --release
# ثم فحص في Xcode
```

---

## ❓ مشاكل شائعة وحلولها

### المشكلة 1: خطأ في Firebase
**الحل:** تأكد من تحديث ملفات `google-services.json` و `GoogleService-Info.plist`

### المشكلة 2: خطأ في Build
**الحل:** 
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean
cd ios && rm -rf Pods && pod install
```

### المشكلة 3: Deep Links لا تعمل
**الحل:** تحديث الـ Deep Links في `AndroidManifest.xml` بالـ Package الجديد

---

## ✅ قائمة التحقق النهائية

- [ ] تغيير `applicationId` في `build.gradle.kts`
- [ ] تغيير `namespace` في `build.gradle.kts`
- [ ] تغيير Bundle Identifier في Xcode
- [ ] تحديث ملفات Firebase
- [ ] اختبار التطبيق بعد التغيير
- [ ] التأكد من عمل الإشعارات
- [ ] التأكد من عمل Firebase Auth
- [ ] التأكد من عمل Google Maps

---

## 📱 Package Name الموصى به لتطبيق زفة:

```
com.zafa.app
```

أو

```
com.zaffaapp.iraq
```

---

**ملاحظة مهمة:** بعد تغيير Package Name، لن تتمكن من تحديث التطبيق القديم - سيكون تطبيق جديد تماماً!
