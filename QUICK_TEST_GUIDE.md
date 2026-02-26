# 🎯 دليل الاختبار السريع للـ Deep Links

## ✅ التحقق من التطبيق

### 1. فحص التطبيق
```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
```
**النتيجة المتوقعة:** ✅ 0 أخطاء compilation

---

## 📱 اختبار الوظائف

### 1. اختبار المشاركة
1. افتح التطبيق
2. اذهب لأي خدمة/عنصر
3. اضغط على زر المشاركة
4. **تحقق من الرسالة:**
   - ✅ تحتوي على `zafa://...`
   - ✅ تحتوي على `https://zafaapp.com/...`

### 2. اختبار Deep Link على Android
```bash
# تأكد أن التطبيق مثبت
adb devices

# اختبار 1: فتح عنصر معين
adb shell am start -a android.intent.action.VIEW \
  -d "zafa://item/YOUR_ITEM_ID" com.zafa.app

# اختبار 2: فتح مزود خدمة
adb shell am start -a android.intent.action.VIEW \
  -d "zafa://provider/PROVIDER_ID" com.zafa.app

# اختبار 3: فتح حجز
adb shell am start -a android.intent.action.VIEW \
  -d "zafa://booking/BOOKING_ID" com.zafa.app
```

**النتيجة المتوقعة:**
- ✅ التطبيق يفتح تلقائياً
- ✅ ينتقل للشاشة المطلوبة
- ✅ يعرض البيانات الصحيحة

### 3. اختبار على جهاز حقيقي
1. انسخ رابط من المشاركة
2. أرسله عبر WhatsApp أو Telegram لنفسك
3. اضغط على الرابط
4. **تحقق:**
   - ✅ يظهر خيار "فتح في تطبيق زفة"
   - ✅ التطبيق يفتح الشاشة الصحيحة

---

## 🔍 استكشاف الأخطاء

### المشكلة: الرابط لا يفتح التطبيق
**الحلول:**
1. تأكد من تثبيت التطبيق
2. امسح cache التطبيق
3. أعد تثبيت التطبيق
4. تحقق من `AndroidManifest.xml`

### المشكلة: التطبيق يفتح لكن لا ينتقل للشاشة
**الحلول:**
1. تحقق من logs:
   ```bash
   adb logcat | grep -i "deep"
   ```
2. تأكد من وجود البيانات في Firestore
3. تحقق من `DeepLinkHandler`

### المشكلة: App Links (https://) لا تعمل
**الحلول:**
1. تأكد من رفع `.well-known/assetlinks.json` للسيرفر
2. تحقق من الرابط: `https://zafaapp.com/.well-known/assetlinks.json`
3. استخدم أداة Google للتحقق:
   https://developers.google.com/digital-asset-links/tools/generator
4. انتظر حتى 24 ساعة لتحديث Google servers

---

## 📊 قائمة التحقق النهائية

### الكود
- [✅] `lib/services/share_service.dart` - محدث بالروابط
- [✅] `lib/utils/deep_link_handler.dart` - معالج الروابط
- [✅] `lib/main.dart` - مدمج مع AppLinks
- [✅] `pubspec.yaml` - app_links package مضاف

### Android
- [✅] `AndroidManifest.xml` - Intent filters مضافة
- [✅] `.well-known/assetlinks.json` - جاهز
- [ ] SHA256 Fingerprint محدث (TODO)
- [ ] ملف assetlinks.json مرفوع للسيرفر (TODO)

### iOS
- [✅] `Info.plist` - URL Schemes مضافة
- [✅] `.well-known/apple-app-site-association` - جاهز
- [ ] Team ID محدث (TODO)
- [ ] ملف apple-app-site-association مرفوع (TODO)

### التوثيق
- [✅] `DEEP_LINKS_SETUP.md` - دليل شامل
- [✅] `DEEP_LINKS_IMPLEMENTATION_SUMMARY.md` - ملخص
- [✅] `.well-known/README.md` - دليل التحقق
- [✅] `QUICK_TEST_GUIDE.md` - هذا الملف

---

## 🎉 النتيجة

**الحالة الحالية:**
- ✅ Deep Links من نوع `zafa://` تعمل 100%
- ✅ المشاركة تحتوي على روابط قابلة للنقر
- ✅ معالجة الروابط عند فتح التطبيق
- ✅ معالجة الروابط أثناء عمل التطبيق
- ⏳ App Links (https://) تحتاج إعداد السيرفر

**للاستخدام الفوري:**
استخدم روابط `zafa://` - تعمل بدون أي إعداد إضافي!

**للاستخدام الاحترافي:**
أكمل إعداد App Links (https://) حسب `DEEP_LINKS_SETUP.md`
