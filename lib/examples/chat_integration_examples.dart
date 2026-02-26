/// 🎯 أمثلة على دمج نظام المحادثات في التطبيق
///
/// هذا الملف يحتوي على أمثلة عملية لكيفية إضافة المحادثات في الصفحات المختلفة
library;

import 'package:flutter/material.dart';
import '../utils/chat_helper.dart';
import '../screens/chats_list_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// مثال 1: إضافة أيقونة المحادثات في AppBar
/// ═══════════════════════════════════════════════════════════════════════════

class ExampleAppBarWithChats extends StatelessWidget {
  const ExampleAppBarWithChats({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('الرئيسية'),
      actions: [
        // أيقونة المحادثات مع عداد
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatsListScreen(),
                  ),
                );
              },
            ),
            // عداد الرسائل غير المقروءة
            Positioned(right: 8, top: 8, child: ChatHelper.buildUnreadBadge()),
          ],
        ),
      ],
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// مثال 2: زر المحادثة في صفحة تفاصيل مزود الخدمة
/// ═══════════════════════════════════════════════════════════════════════════

class ExampleProviderDetailsWithChat extends StatelessWidget {
  final String providerId;
  final String providerName;
  final String? providerImage;

  const ExampleProviderDetailsWithChat({
    super.key,
    required this.providerId,
    required this.providerName,
    this.providerImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(providerName)),
      body: Column(
        children: [
          // معلومات مزود الخدمة
          const Text('تفاصيل مزود الخدمة...'),

          const SizedBox(height: 20),

          // أزرار الإجراءات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // زر الحجز
              ElevatedButton.icon(
                onPressed: () {
                  // منطق الحجز
                },
                icon: const Icon(Icons.calendar_today),
                label: const Text('حجز'),
              ),

              // زر المحادثة
              ChatHelper.buildChatButton(
                context: context,
                otherUserId: providerId,
                otherUserName: providerName,
                otherUserImage: providerImage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// مثال 3: إضافة زر "تواصل مع المالك" في شاشة الدعم
/// ═══════════════════════════════════════════════════════════════════════════

class ExampleSupportScreenWithOwnerChat extends StatelessWidget {
  const ExampleSupportScreenWithOwnerChat({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدعم')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent, size: 80, color: Color(0xFF6E1229)),
            const SizedBox(height: 20),
            const Text('كيف يمكننا مساعدتك؟', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 30),

            // زر التواصل مع المالك
            ElevatedButton.icon(
              onPressed: () => ChatHelper.startChatWithOwner(context),
              icon: const Icon(Icons.chat),
              label: const Text('تواصل مع المالك'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6E1229),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// مثال 4: إضافة المحادثات في Bottom Navigation
/// ═══════════════════════════════════════════════════════════════════════════

class ExampleBottomNavWithChats extends StatefulWidget {
  const ExampleBottomNavWithChats({super.key});

  @override
  State<ExampleBottomNavWithChats> createState() =>
      _ExampleBottomNavWithChatsState();
}

class _ExampleBottomNavWithChatsState extends State<ExampleBottomNavWithChats> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const Center(child: Text('الرئيسية')),
    const Center(child: Text('الحجوزات')),
    const ChatsListScreen(), // شاشة المحادثات
    const Center(child: Text('الحساب')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6E1229),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'الحجوزات',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.chat),
                Positioned(
                  right: 0,
                  top: 0,
                  child: ChatHelper.buildUnreadBadge(),
                ),
              ],
            ),
            label: 'المحادثات',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'الحساب',
          ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// مثال 5: زر عائم للمحادثة مع مزود الخدمة
/// ═══════════════════════════════════════════════════════════════════════════

class ExampleScreenWithFloatingChatButton extends StatelessWidget {
  final String providerId;
  final String providerName;

  const ExampleScreenWithFloatingChatButton({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العنصر')),
      body: const Center(child: Text('محتوى الصفحة...')),
      floatingActionButton: ChatHelper.buildChatButton(
        context: context,
        otherUserId: providerId,
        otherUserName: providerName,
        isFloating: true,
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// مثال 6: قائمة مزودي الخدمة مع زر محادثة لكل مزود
/// ═══════════════════════════════════════════════════════════════════════════

class ExampleProvidersListWithChat extends StatelessWidget {
  final List<Map<String, dynamic>> providers = [
    {'id': '1234', 'name': 'قاعة الأحلام', 'image': null},
    {'id': '5678', 'name': 'فندق النجوم', 'image': null},
  ];

  ExampleProvidersListWithChat({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مزودو الخدمات')),
      body: ListView.builder(
        itemCount: providers.length,
        itemBuilder: (context, index) {
          final provider = providers[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: CircleAvatar(child: Text(provider['name'][0])),
              title: Text(provider['name']),
              subtitle: const Text('قاعة أعراس'),
              trailing: IconButton(
                icon: const Icon(Icons.chat, color: Color(0xFF6E1229)),
                onPressed: () => ChatHelper.startChatWithUser(
                  context: context,
                  otherUserId: provider['id'],
                  otherUserName: provider['name'],
                  otherUserImage: provider['image'],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ملاحظات مهمة:
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// 1. تأكد من استيراد الملفات المطلوبة:
///    import '../utils/chat_helper.dart';
///    import '../screens/chats_list_screen.dart';
/// 
/// 2. يجب أن يكون المستخدم مسجل دخول (currentUserId موجود في SharedPreferences)
/// 
/// 3. لإضافة المحادثات في أي صفحة:
///    - استخدم ChatHelper.buildChatButton() لزر محادثة
///    - استخدم ChatHelper.buildUnreadBadge() لعداد الرسائل
///    - استخدم ChatHelper.startChatWithUser() لفتح محادثة مباشرة
/// 
/// 4. رقم هاتف المالك: 0772187444 (يمكن تغييره في chat_helper.dart)
/// 
/// 5. الألوان الرئيسية: #2B0606 (ماروني غامق)
