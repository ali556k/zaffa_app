# كيفية نشر صفحة سياسة الخصوصية

تم إنشاء صفحة سياسة الخصوصية في الملف: `web/privacy_policy.html`

## طريقة 1: رفع الملف على GitHub Pages

### الخطوات:

1. **إنشاء مستودع GitHub جديد**:
   - قم بإنشاء مستودع جديد على GitHub (مثلاً باسم `privacy-policy`)
   - اجعله Public

2. **رفع ملف HTML**:
   ```bash
   git init
   git add web/privacy_policy.html
   git commit -m "Add privacy policy"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/privacy-policy.git
   git push -u origin main
   ```

3. **تفعيل GitHub Pages**:
   - اذهب إلى Settings → Pages
   - اختر Branch: main
   - اختر مجلد: / (root)
   - انقر على Save

4. **الحصول على الرابط**:
   - سيكون الرابط: `https://YOUR_USERNAME.github.io/privacy-policy/web/privacy_policy.html`
   - قم بتحديث الرابط في `login_screen.dart`

---

## طريقة 2: استخدام Firebase Hosting

### الخطوات:

1. **تثبيت Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```

2. **تسجيل الدخول إلى Firebase**:
   ```bash
   firebase login
   ```

3. **تهيئة Firebase Hosting**:
   ```bash
   firebase init hosting
   ```
   - اختر مجلد: web
   - اختر: Configure as single-page app? No
   - اختر: Set up automatic builds? No

4. **نشر الموقع**:
   ```bash
   firebase deploy --only hosting
   ```

5. **الحصول على الرابط**:
   - سيكون الرابط: `https://YOUR_PROJECT_ID.web.app/privacy_policy.html`
   - قم بتحديث الرابط في `login_screen.dart`

---

## طريقة 3: استخدام Google Sites

### الخطوات:

1. **افتح Google Sites**:
   - اذهب إلى [sites.google.com](https://sites.google.com)

2. **إنشاء موقع جديد**:
   - انقر على "إنشاء"
   - اختر "موقع فارغ"

3. **نسخ المحتوى**:
   - افتح `web/privacy_policy.html` في المتصفح
   - انسخ المحتوى النصي (بدون HTML tags)
   - ضعه في Google Sites مع تنسيق مشابه

4. **نشر الموقع**:
   - انقر على "نشر"
   - احصل على الرابط

5. **تحديث الرابط**:
   - قم بتحديث الرابط في `login_screen.dart`

---

## تحديث الرابط في التطبيق

في ملف `lib/screens/login_screen.dart`، قم بتغيير هذا السطر:

```dart
final Uri url = Uri.parse('https://zaffaa00.github.io/privacy_policy.html');
```

إلى الرابط الفعلي لصفحة سياسة الخصوصية الخاصة بك.

---

## ملاحظات مهمة

- ✅ تم إضافة الرابط في صفحة تسجيل الدخول تحت "نسيت كلمة المرور"
- ✅ تم إنشاء صفحة HTML احترافية بتصميم جميل
- ✅ الصفحة responsive وتعمل على جميع الأجهزة
- ✅ تم إضافة جميع المعلومات المطلوبة

## معلومات الاتصال في الصفحة

- البريد الإلكتروني: zaffaa00@gmail.com
- رقم الهاتف: 07782297857
