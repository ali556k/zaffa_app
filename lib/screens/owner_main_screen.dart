import 'package:flutter/material.dart';
import 'admin_screen.dart';
import 'admin_provider_requests_screen.dart';
import 'admin_bookings_screen.dart';
import 'owner_chats_screen.dart';

/// شاشة المالك الرئيسية مع شريط تنقل سفلي
class OwnerMainScreen extends StatefulWidget {
  const OwnerMainScreen({super.key});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    AdminScreen(), // إدارة الخدمات
    AdminProviderRequestsScreen(), // طلبات المزودين
    AdminBookingsScreen(), // الحجوزات
    OwnerChatsScreen(), // المحادثات
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.98),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: const Color(0xFF2B0606),
              unselectedItemColor: Colors.grey.shade600,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              selectedIconTheme: const IconThemeData(size: 26),
              unselectedIconTheme: const IconThemeData(size: 22),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'إدارة الخدمات',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment),
                  label: 'الطلبات',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.book_online),
                  label: 'الحجوزات',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat),
                  label: 'المحادثات',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
