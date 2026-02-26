# إرشادات إصلاح مشكلة Google Maps API

## المشكلة
لا تظهر الخريطة في شاشة تحديد الموقع بسبب عدم وجود مفتاح Google Maps API صالح.

## الحل الكامل

### 1. إنشاء مفتاح Google Maps API

1. **اذهب إلى Google Cloud Console:**
   - افتح: https://console.cloud.google.com/
   - سجل الدخول بحساب Google

2. **أنشئ مشروع جديد:**
   - اضغط على قائمة المشاريع في الأعلى
   - اضغط "New Project"
   - أدخل اسم المشروع (مثل: "zafa-app")
   - اضغط "Create"

3. **فعّل Maps SDK for Android:**
   - في القائمة الجانبية، اذهب إلى "APIs & Services" → "Library"
   - ابحث عن "Maps SDK for Android"
   - اضغط عليه ثم اضغط "Enable"

4. **أنشئ مفتاح API:**
   - اذهب إلى "APIs & Services" → "Credentials"
   - اضغط "Create Credentials" → "API Key"
   - انسخ المفتاح الذي ظهر

### 2. إضافة المفتاح للتطبيق

1. **افتح ملف AndroidManifest.xml:**
   ```
   android/app/src/main/AndroidManifest.xml
   ```

2. **استبدل المفتاح:**
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="ضع مفتاحك هنا"/>
   ```

### 3. إعدادات الأمان (اختيارية)

1. **تقييد المفتاح:**
   - في Google Cloud Console، اذهب إلى "Credentials"
   - اضغط على المفتاح الذي أنشأته
   - في "Application restrictions"، اختر "Android apps"
   - أضف:
     - Package name: `com.example.zafa_app`
     - SHA-1 certificate fingerprint: (يمكن الحصول عليه من Android Studio)

## الحلول البديلة المتاحة

حتى لو لم تحل مشكلة مفتاح API، يمكن للمستخدمين تحديد الموقع عبر:

1. **اختيار المحافظة:** زر "محافظات" لاختيار من قائمة المحافظات العراقية
2. **إدخال إحداثيات:** زر "يدوي" لإدخال خط العرض والطول
3. **موقع بغداد الافتراضي:** زر "بغداد" لاستخدام إحداثيات بغداد

## فحص الحل

بعد إضافة مفتاح API صالح:
1. أعد تشغيل التطبيق
2. اذهب إلى شاشة تحديد الموقع
3. يجب أن تظهر الخريطة بشكل طبيعي

## الدعم

إذا واجهت مشاكل، تحقق من:
- تفعيل "Maps SDK for Android" في Google Cloud Console
- صحة مفتاح API في AndroidManifest.xml
- اتصال الإنترنت في التطبيق
