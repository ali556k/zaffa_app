# كيفية إضافة زر "إدارة الحجوزات" لمزود الخدمة

## الطريقة السريعة

### 1. إيجاد شاشة لوحة تحكم المزود
ابحث عن ملف مثل:
- `provider_dashboard_screen.dart`
- `provider_home_screen.dart`
- أو أي شاشة رئيسية للمزود

### 2. إضافة الاستيراد في أعلى الملف:
```dart
import 'provider_bookings_management_screen.dart';
```

### 3. إضافة زر أو بطاقة للانتقال:

#### الطريقة الأولى - زر عائم (Floating Action Button):
```dart
floatingActionButton: FloatingActionButton.extended(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProviderBookingsManagementScreen(),
      ),
    );
  },
  icon: const Icon(Icons.event_note),
  label: const Text('إدارة الحجوزات'),
  backgroundColor: const Color(0xFF1E88E5),
),
```

#### الطريقة الثانية - بطاقة في الشبكة (Grid):
```dart
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProviderBookingsManagementScreen(),
      ),
    );
  },
  child: Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.orange,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.3),
          spreadRadius: 2,
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.event_note,
          size: 48,
          color: Colors.white,
        ),
        const SizedBox(height: 12),
        const Text(
          'إدارة الحجوزات',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  ),
)
```

#### الطريقة الثالثة - عنصر في قائمة (ListView):
```dart
ListTile(
  leading: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF1E88E5).withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.event_note,
      color: Color(0xFF1E88E5),
      size: 28,
    ),
  ),
  title: const Text(
    'إدارة الحجوزات',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  ),
  subtitle: const Text(
    'عرض وإلغاء الحجوزات',
    style: TextStyle(fontSize: 14),
  ),
  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProviderBookingsManagementScreen(),
      ),
    );
  },
)
```

## مثال كامل لبطاقة في GridView

```dart
// في شاشة لوحة التحكم
GridView.count(
  crossAxisCount: 2,
  padding: const EdgeInsets.all(16),
  mainAxisSpacing: 16,
  crossAxisSpacing: 16,
  children: [
    // البطاقة الأولى - العناصر المنشورة
    _buildDashboardCard(
      title: 'عناصري المنشورة',
      icon: Icons.inventory,
      color: Colors.blue,
      onTap: () {
        // الانتقال لشاشة العناصر
      },
    ),
    
    // البطاقة الثانية - إدارة الحجوزات (جديد)
    _buildDashboardCard(
      title: 'إدارة الحجوزات',
      icon: Icons.event_note,
      color: Colors.orange,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProviderBookingsManagementScreen(),
          ),
        );
      },
    ),
    
    // البطاقة الثالثة - الإعدادات
    _buildDashboardCard(
      title: 'الإعدادات',
      icon: Icons.settings,
      color: Colors.green,
      onTap: () {
        // الانتقال لشاشة الإعدادات
      },
    ),
  ],
)

// دالة مساعدة لإنشاء البطاقات
Widget _buildDashboardCard({
  required String title,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
```

## الأيقونات المقترحة

- `Icons.event_note` - دفتر الملاحظات
- `Icons.calendar_today` - تقويم
- `Icons.book_online` - حجز أونلاين
- `Icons.event_available` - حدث متاح
- `Icons.manage_accounts` - إدارة الحسابات

## الألوان المقترحة

```dart
Color(0xFF1E88E5)  // أزرق
Color(0xFFF59E0B)  // برتقالي
Color(0xFF10B981)  // أخضر
Color(0xFF8B5CF6)  // بنفسجي
```

## ملاحظات مهمة

1. ✅ تأكد من إضافة الاستيراد في أعلى الملف
2. ✅ الشاشة تعمل مباشرة بدون تمرير معاملات
3. ✅ تحتاج فقط إلى معرف المزود (يُحمّل تلقائياً من SharedPreferences)
4. ✅ الشاشة تستمع للتحديثات في الوقت الفعلي

## اختبار سريع

بعد إضافة الزر:
1. شغل التطبيق
2. سجل دخول كمزود خدمة
3. اضغط على زر "إدارة الحجوزات"
4. يجب أن تظهر قائمة الحجوزات (أو رسالة "لا توجد حجوزات")

---

**إذا واجهت أي مشكلة، أخبرني!**
