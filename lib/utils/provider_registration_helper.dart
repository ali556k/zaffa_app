import 'package:flutter/material.dart';
import '../screens/provider_service_registration_screen.dart';
import '../screens/main_navigation_screen.dart';

// مثال لكيفية استخدام نظام تسجيل مزود الخدمة الجديد
// يمكن استدعاءه بعد اكتمال تسجيل حساب مزود الخدمة

void navigateToProviderRegistration(BuildContext context, {
  required String providerId,
  required String providerName,
  required String providerPhone,
}) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => ProviderServiceRegistrationScreen(
        providerId: providerId,
        providerName: providerName,
        providerPhone: providerPhone,
      ),
    ),
  );
}

// للانتقال المباشر للصفحة الرئيسية لمزود خدمة موجود
void navigateToProviderMainScreen(BuildContext context) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => const MainNavigationScreen(isAdmin: true), // تمرير isAdmin للمزود
    ),
  );
}

// مثال على الاستخدام:

// للمزودين الجدد - يمر بعملية التسجيل الكاملة
/*
void onNewProviderAccountCompleted() {
  navigateToProviderRegistration(
    context,
    providerId: '07721234567',
    providerName: 'أحمد محمد',
    providerPhone: '07721234567',
  );
}
*/

// للمزودين الموجودين - انتقال مباشر للصفحة الرئيسية
/*
void onExistingProviderLogin() {
  navigateToProviderMainScreen(
    context,
    providerId: '07721234567',
    providerName: 'أحمد محمد',
  );
}
*/
