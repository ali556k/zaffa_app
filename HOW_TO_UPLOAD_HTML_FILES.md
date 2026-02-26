# 🌐 دليل رفع ملفات HTML (سياسة الخصوصية وشروط الاستخدام)

## الملفات المطلوب رفعها:
- `web/privacy_policy.html` ✅ جاهز
- `web/terms_of_service.html` ✅ جاهز

---

## 📌 الطرق المتاحة (اختر إحداها):

### 1️⃣ GitHub Pages (مجاني - سهل - موصى به)

#### الخطوات:

1. **أنشئ حساب على GitHub:**
   - اذهب إلى [github.com](https://github.com)
   - سجّل حساب جديد إذا لم يكن لديك

2. **أنشئ Repository جديد:**
   - اضغط على `New Repository`
   - اسم الـ Repo: `privacy-policies` أو أي اسم
   - اجعله **Public**
   - اضغط `Create Repository`

3. **ارفع الملفات:**
   - اضغط `Add file` → `Upload files`
   - اسحب الملفين:
     * `privacy_policy.html`
     * `terms_of_service.html`
   - اضغط `Commit changes`

4. **فعّل GitHub Pages:**
   - اذهب إلى `Settings` في الـ Repo
   - من القائمة الجانبية: `Pages`
   - تحت **Source**: اختر `main` branch
   - اضغط `Save`

5. **احصل على الروابط:**
   بعد دقائق ستحصل على:
   ```
   https://YOUR-USERNAME.github.io/privacy-policies/privacy_policy.html
   https://YOUR-USERNAME.github.io/privacy-policies/terms_of_service.html
   ```

6. **حدّث التطبيق:**
   استبدل الروابط في `lib/screens/login_screen.dart`:
   ```dart
   // سياسة الخصوصية
   'https://YOUR-USERNAME.github.io/privacy-policies/privacy_policy.html'
   
   // شروط الاستخدام
   'https://YOUR-USERNAME.github.io/privacy-policies/terms_of_service.html'
   ```

---

### 2️⃣ Firebase Hosting (مجاني - متقدم)

#### الخطوات:

1. **ثبّت Firebase CLI:**
   ```bash
   npm install -g firebase-tools
   ```

2. **سجّل دخول:**
   ```bash
   firebase login
   ```

3. **أنشئ مجلد للرفع:**
   ```bash
   # في مجلد التطبيق
   mkdir public_web
   cd public_web
   ```

4. **انسخ الملفات:**
   ```bash
   cp ../web/privacy_policy.html .
   cp ../web/terms_of_service.html .
   ```

5. **فعّل Firebase Hosting:**
   ```bash
   firebase init hosting
   ```
   
   اختر:
   - المشروع الخاص بك
   - Public directory: `public_web`
   - Configure as single-page app: `No`
   - Overwrite index.html: `No`

6. **ارفع الملفات:**
   ```bash
   firebase deploy --only hosting
   ```

7. **احصل على الروابط:**
   ```
   https://YOUR-PROJECT-ID.web.app/privacy_policy.html
   https://YOUR-PROJECT-ID.web.app/terms_of_service.html
   ```

---

### 3️⃣ Google Sites (سهل جداً - لكن محدود)

#### الخطوات:

1. **اذهب إلى Google Sites:**
   - [sites.google.com](https://sites.google.com)
   - سجّل دخول بحساب Google

2. **أنشئ موقع جديد:**
   - اضغط `+ (فارغ)` لإنشاء موقع جديد
   - اسم الموقع: "تطبيق زفة - السياسات"

3. **أنشئ صفحة سياسة الخصوصية:**
   - اضغط `صفحات` → `صفحة جديدة`
   - الاسم: "سياسة الخصوصية"
   - انسخ محتوى `privacy_policy.html` (النص فقط، بدون HTML)
   - الصق المحتوى

4. **أنشئ صفحة شروط الاستخدام:**
   - نفس الخطوات السابقة
   - الاسم: "شروط الاستخدام"

5. **انشر الموقع:**
   - اضغط زر `نشر` في الأعلى
   - اختر عنوان URL
   - مثال: `zafa-app`
   - ستحصل على: `sites.google.com/view/zafa-app`

6. **الروابط:**
   ```
   https://sites.google.com/view/zafa-app/privacy-policy
   https://sites.google.com/view/zafa-app/terms-of-service
   ```

⚠️ **ملاحظة:** Google Sites لا يدعم HTML مخصص، فقط محتوى نصي منسّق!

---

## ✅ قائمة التحقق بعد الرفع:

- [ ] جرّب فتح رابط سياسة الخصوصية من المتصفح
- [ ] جرّب فتح رابط شروط الاستخدام من المتصفح
- [ ] تأكد من ظهور التنسيق بشكل صحيح
- [ ] تأكد من عمل روابط البريد والهاتف
- [ ] حدّث الروابط في `login_screen.dart`
- [ ] اختبر الروابط من داخل التطبيق

---

## 📝 الروابط الحالية في التطبيق (يجب تحديثها):

### في `login_screen.dart`:

**سياسة الخصوصية:**
```dart
'https://sites.google.com/view/zaffa-iq/...'  // رابط مؤقت
```

**شروط الاستخدام:**
```dart
'https://zaffaa00.github.io/terms_of_service.html'  // رابط مؤقت
```

---

## 🎯 التوصية:

**استخدم GitHub Pages** لأنه:
- مجاني تماماً ✅
- سهل الاستخدام ✅
- يدعم HTML مخصص ✅
- روابط نظيفة وقصيرة ✅
- سريع وموثوق ✅

---

## 🚀 خطوات سريعة (GitHub Pages):

```bash
# 1. أنشئ Repo على GitHub
# 2. ارفع الملفات
# 3. فعّل Pages من Settings

# 4. انسخ الروابط وحدّث التطبيق
flutter pub get
flutter run
```

---

## ❓ أسئلة شائعة:

**س: هل يمكن تغيير الروابط لاحقاً؟**
ج: نعم، يمكنك تحديث الروابط في `login_screen.dart` وبناء نسخة جديدة.

**س: هل الروابط ستعمل بدون إنترنت؟**
ج: لا، المستخدمون يحتاجون إنترنت لفتح السياسات.

**س: هل يجب رفع الملفات باللغة الإنجليزية؟**
ج: لا، الملفات بالعربية وستعمل بشكل صحيح.

---

## 📧 عند النشر على المتاجر:

سيطلب منك:
- **Google Play Console:** رابط سياسة الخصوصية (إجباري)
- **App Store Connect:** رابط سياسة الخصوصية (إجباري)
- **كلاهما:** رابط شروط الاستخدام (موصى به)

تأكد من أن الروابط تعمل قبل تقديم التطبيق!
