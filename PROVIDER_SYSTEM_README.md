# نظام تسجيل مزودي الخدمة المحدث

## نظرة عامة

تم إنشاء نظام متكامل لتسجيل مزودي الخدمة يتضمن 3 مراحل رئيسية:

1. **تسجيل معلومات الخدمة** (`ProviderServiceRegistrationScreen`)
2. **إضافة عناصر الخدمة** (`ProviderItemsRegistrationScreen`) 
3. **الصفحة الرئيسية لمزود الخدمة** (`ProviderMainScreen`)

## الملفات المنشأة

- `lib/screens/provider_service_registration_screen.dart` - واجهة تسجيل معلومات الخدمة
- `lib/screens/provider_items_registration_screen.dart` - واجهة إضافة العناصر
- `lib/screens/provider_main_screen.dart` - الصفحة الرئيسية لمزود الخدمة
- `lib/utils/provider_registration_helper.dart` - مساعد للتنقل

## كيفية الاستخدام

### 1. بعد اكتمال تسجيل حساب مزود الخدمة

```dart
import 'package:clean_app/utils/provider_registration_helper.dart';

// بدلاً من فتح الواجهة القديمة، استخدم:
navigateToProviderRegistration(
  context,
  providerId: userPhone,
  providerName: userName,
  providerPhone: userPhone,
);
```

### 2. في ملف تسجيل الدخول أو إنشاء الحساب

```dart
void onProviderAccountCompleted() {
  // استبدال الكود القديم بالجديد
  navigateToProviderRegistration(
    context,
    providerId: currentUserId,
    providerName: currentUserName,
    providerPhone: currentUserPhone,
  );
}
```

## المزايا الجديدة

### واجهة تسجيل معلومات الخدمة
- ✅ تصميم عصري ومتدرج الألوان
- ✅ اختيار صورة للخدمة
- ✅ تحديد نوع الخدمة من قائمة منسدلة
- ✅ تحديد الموقع على الخريطة التفاعلية
- ✅ إدخال معلومات بطاقة الائتمان
- ✅ التحقق من صحة البيانات

### واجهة إضافة العناصر
- ✅ قائمة ديناميكية للعناصر
- ✅ إمكانية إضافة/تعديل/حذف العناصر
- ✅ رفع 3 صور على الأقل لكل عنصر
- ✅ تفاصيل شاملة لكل عنصر (اسم، تفاصيل، سعر، سعة)
- ✅ معاينة فورية للعناصر المضافة
- ✅ إرسال الطلب للإدارة بعد الانتهاء

### الصفحة الرئيسية لمزود الخدمة
- ✅ عرض جميع العناصر في تخطيط جذاب
- ✅ تبويبات منفصلة للعناصر والتقويم
- ✅ إمكانية تعديل وحذف العناصر
- ✅ تقويم تفاعلي لإدارة الحجوزات
- ✅ زر عائم لإضافة عناصر جديدة
- ✅ حالة العناصر (نشط/معلق)
- ✅ إحصائيات مبسطة

## التقنيات المستخدمة

- **Flutter Material Design 3**
- **Firebase Firestore** لحفظ البيانات
- **Firebase Storage** لرفع الصور
- **Google Maps** لتحديد الموقع
- **Table Calendar** لإدارة التقويم
- **Image Picker** لاختيار الصور

## هيكل قاعدة البيانات

### مجموعة provider_requests
```json
{
  "serviceName": "قاعة الأفراح الذهبية",
  "serviceType": "قاعات اعراس",
  "serviceImageUrl": "https://...",
  "location": {
    "latitude": 33.3152,
    "longitude": 44.3661
  },
  "area": "بغداد - الكرادة",
  "creditCard": "1234567890123456",
  "providerId": "07721234567",
  "providerName": "أحمد محمد",
  "providerPhone": "07721234567",
  "items": [
    {
      "name": "قاعة الماسة",
      "details": "قاعة فاخرة تتسع لـ 300 شخص",
      "price": "500000",
      "capacity": "300 شخص",
      "imageUrls": ["https://...", "https://...", "https://..."]
    }
  ],
  "status": "pending",
  "createdAt": "timestamp",
  "submittedAt": "timestamp"
}
```

### مجموعة services/{serviceType}/items
```json
{
  "name": "قاعة الماسة",
  "details": "قاعة فاخرة تتسع لـ 300 شخص",
  "price": "500000",
  "capacity": "300 شخص",
  "imageUrls": ["https://...", "https://...", "https://..."],
  "providerId": "07721234567",
  "providerName": "أحمد محمد",
  "location": "بغداد - الكرادة",
  "isActive": true,
  "createdAt": "timestamp"
}
```

## خطوات التطبيق

1. **احذف الواجهة القديمة** لتسجيل مزودي الخدمة
2. **استبدل النداءات القديمة** بـ `navigateToProviderRegistration()`
3. **تأكد من إضافة الحزم المطلوبة** في `pubspec.yaml`
4. **اختبر التدفق الكامل** من التسجيل إلى الصفحة الرئيسية

## ملاحظات مهمة

- النظام مدمج مع نظام الموافقة الحالي في صفحة الإدارة
- يتم حفظ جميع البيانات في Firebase تلقائياً
- الصور يتم ضغطها تلقائياً لتوفير مساحة التخزين
- التحقق من صحة البيانات شامل في جميع المراحل
- التصميم متجاوب ويعمل على جميع أحجام الشاشات

---

**ملاحظة**: تأكد من تحديث أذونات Firebase Storage وFirestore للسماح بالقراءة والكتابة للمستخدمين المصرح لهم.
