# Digital Asset Links - دليل الإعداد

## 📋 نظرة عامة
هذا الملف يُستخدم للتحقق من صحة App Links على Android.

---

## 🔧 كيفية الحصول على SHA256 Fingerprint

### 1. للنسخة Debug (أثناء التطوير)

**Windows:**
```powershell
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Mac/Linux:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### 2. للنسخة Release (للنشر)

```bash
keytool -list -v -keystore path/to/your/release.keystore -alias your-key-alias
```

### 3. البحث عن السطر

ابحث عن:
```
SHA256: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99
```

### 4. انسخ القيمة
انسخ القيمة (مع `:` بدون مسافات) وضعها في `assetlinks.json`

---

## 📍 أين تضع هذا الملف؟

رفعه على السيرفر في المسار:
```
https://zafaapp.com/.well-known/assetlinks.json
```

### متطلبات:
- ✅ يجب أن يكون HTTPS (ليس HTTP)
- ✅ Content-Type: `application/json`
- ✅ لا يوجد redirect
- ✅ متاح للعموم (بدون authentication)

---

## ✅ التحقق من صحة الإعداد

### استخدم أداة Google
https://developers.google.com/digital-asset-links/tools/generator

### تحقق يدوياً
```bash
curl -I https://zafaapp.com/.well-known/assetlinks.json
```

---

## 📝 مثال كامل

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.zafa.app",
    "sha256_cert_fingerprints": [
      "14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"
    ]
  }
}]
```

---

## 🔄 دعم نسخ متعددة (Debug + Release)

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.zafa.app",
    "sha256_cert_fingerprints": [
      "DEBUG_FINGERPRINT_HERE",
      "RELEASE_FINGERPRINT_HERE"
    ]
  }
}]
```

---

## 🔍 استكشاف الأخطاء

### إذا لم تعمل App Links:

1. **تحقق من الملف متاح:**
   ```bash
   curl https://zafaapp.com/.well-known/assetlinks.json
   ```

2. **تحقق من صحة JSON:**
   https://jsonlint.com

3. **تحقق من Package Name:**
   يجب أن يطابق `applicationId` في `android/app/build.gradle`

4. **امسح cache التطبيق:**
   - Settings > Apps > Zafa > Storage > Clear Data
   - أعد تثبيت التطبيق

5. **انتظر:**
   قد يستغرق الأمر حتى 24 ساعة لتحديث Google servers

6. **استخدم Deep Link Scheme للاختبار الفوري:**
   ```
   zafa://item/abc123
   ```
   (بدون التحقق من الدومين)
