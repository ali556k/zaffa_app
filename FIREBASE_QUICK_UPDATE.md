# 🔥 تحديث Firebase - الخطوات السريعة

## 📱 **للأندرويد (google-services.json):**

### 1. افتح Firebase Console:
```
https://console.firebase.google.com
```

### 2. اختر مشروعك → Settings ⚙️ → Project Settings

### 3. في قسم "Your apps":
- اضغط **Add app**
- اختر **Android**

### 4. املأ المعلومات:
```
Package name: com.zafa.app
App nickname: Zafa App
```
اضغط **Register app**

### 5. حمّل الملف:
- اضغط **Download google-services.json**

### 6. استبدل الملف:
```powershell
# احذف القديم
Remove-Item "D:\clean_app\android\app\google-services.json"

# انسخ الجديد (غيّر المسار)
Copy-Item "C:\Users\YOURNAME\Downloads\google-services.json" "D:\clean_app\android\app\"
```

---

## 🍎 **لـ iOS (GoogleService-Info.plist):**

### 1. في نفس Project Settings:
- اضغط **Add app**
- اختر **iOS**

### 2. املأ:
```
Bundle ID: com.zafa.app
App nickname: Zafa App iOS
```
اضغط **Register app**

### 3. حمّل الملف:
- اضغط **Download GoogleService-Info.plist**

### 4. استبدل الملف:
```powershell
# احذف القديم
Remove-Item "D:\clean_app\ios\Runner\GoogleService-Info.plist"

# انسخ الجديد
Copy-Item "C:\Users\YOURNAME\Downloads\GoogleService-Info.plist" "D:\clean_app\ios\Runner\"
```

---

## 🧹 **نظّف وأعد البناء:**

```bash
# نظّف
flutter clean

# احصل على الحزم
flutter pub get

# ابنِ التطبيق
flutter build appbundle --release
```

---

## ✅ **تأكد من النجاح:**

يجب أن ترى:
```
✓ Built build\app\outputs\bundle\release\app-release.aab
```

**بدون أخطاء Firebase!** 🎉

---

## 🔍 **تحقق من الملف الجديد:**

افتح: `android\app\google-services.json`

يجب أن يحتوي على:
```json
"package_name": "com.zafa.app"
```

وليس `com.example.zafa_app` ❌

---

## 📖 **للدليل الكامل المفصّل:**

راجع: [FIREBASE_UPDATE_GUIDE.md](FIREBASE_UPDATE_GUIDE.md)

---

**الوقت المطلوب:** 10-15 دقيقة ⏱️
