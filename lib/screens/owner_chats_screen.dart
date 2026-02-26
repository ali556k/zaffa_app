import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';
import 'package:intl/intl.dart' as intl;

/// شاشة محادثات المالك مع تبويبين: محادثات الزبائن ومحادثات المزودين
class OwnerChatsScreen extends StatefulWidget {
  const OwnerChatsScreen({super.key});

  @override
  State<OwnerChatsScreen> createState() => _OwnerChatsScreenState();
}

class _OwnerChatsScreenState extends State<OwnerChatsScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId =
          prefs.getString('currentUserId') ?? prefs.getString('user_phone');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        title: const Text(
          'المحادثات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'محادثات الزبائن'),
            Tab(text: 'محادثات المزودين'),
          ],
        ),
      ),
      body: _currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChatsList(userType: 'customer'),
                _buildChatsList(userType: 'provider'),
              ],
            ),
    );
  }

  Widget _buildChatsList({required String userType}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: _currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  userType == 'customer'
                      ? 'لا توجد محادثات مع الزبائن'
                      : 'لا توجد محادثات مع المزودين',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // فلترة المحادثات حسب نوع المستخدم
        var filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final otherUserId = _chatService.getOtherUserId(
            data,
            _currentUserId!,
          );

          // للحصول على نوع المستخدم، نتحقق من userInfo
          final userInfo = data['userInfo'] as Map<String, dynamic>?;
          if (userInfo == null || !userInfo.containsKey(otherUserId)) {
            return false;
          }

          final otherUserInfo = userInfo[otherUserId] as Map<String, dynamic>?;
          final role = otherUserInfo?['role'] as String?;

          // فلترة حسب النوع المطلوب
          if (userType == 'customer') {
            return role == 'customer' || role == null; // null قد يكون عميل قديم
          } else {
            return role == 'provider';
          }
        }).toList();

        // ترتيب المحادثات من الأحدث للأقدم (client-side sorting)
        filteredDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTimestamp = aData['lastTimestamp'] as Timestamp?;
          final bTimestamp = bData['lastTimestamp'] as Timestamp?;

          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;

          return bTimestamp.compareTo(aTimestamp);
        });

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  userType == 'customer'
                      ? 'لا توجد محادثات مع الزبائن'
                      : 'لا توجد محادثات مع المزودين',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final chatDoc = filteredDocs[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final chatId = chatDoc.id;

            final otherUserId = _chatService.getOtherUserId(
              chatData,
              _currentUserId!,
            );
            var otherUserInfo = _chatService.getOtherUserInfo(
              chatData,
              _currentUserId!,
            );

            print('📊 بيانات المحادثة: $chatId');
            print('👤 المستخدم الآخر: $otherUserId');
            print('ℹ️ معلومات المستخدم من المحادثة: $otherUserInfo');

            final lastMessage = chatData['lastMessage'] as String? ?? '';
            final lastTimestamp = chatData['lastTimestamp'] as Timestamp?;
            final unreadCount =
                (chatData['unreadCount']
                        as Map<String, dynamic>?)?[_currentUserId]
                    as int? ??
                0;

            // إذا كانت البيانات ناقصة، اجلبها من Firestore
            if (otherUserInfo['name'] == 'مستخدم' && otherUserId.isNotEmpty) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  String userName = otherUserId;
                  String? userImage;

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>?;
                    userName =
                        userData?['name'] ??
                        userData?['userName'] ??
                        otherUserId;
                    userImage =
                        userData?['imageUrl'] ?? userData?['profileImage'];
                    print('✅ تم جلب اسم المستخدم من Firestore: $userName');
                  }

                  return _buildChatTile(
                    chatId: chatId,
                    otherUserId: otherUserId,
                    otherUserName: userName,
                    otherUserImage: userImage,
                    lastMessage: lastMessage,
                    lastTimestamp: lastTimestamp,
                    unreadCount: unreadCount,
                  );
                },
              );
            }

            return _buildChatTile(
              chatId: chatId,
              otherUserId: otherUserId,
              otherUserName: otherUserInfo['name'] ?? otherUserId,
              otherUserImage: otherUserInfo['imageUrl'],
              lastMessage: lastMessage,
              lastTimestamp: lastTimestamp,
              unreadCount: unreadCount,
            );
          },
        );
      },
    );
  }

  Widget _buildChatTile({
    required String chatId,
    required String otherUserId,
    required String otherUserName,
    String? otherUserImage,
    required String lastMessage,
    Timestamp? lastTimestamp,
    required int unreadCount,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          backgroundImage: otherUserImage != null && otherUserImage.isNotEmpty
              ? NetworkImage(otherUserImage)
              : null,
          child: otherUserImage == null || otherUserImage.isEmpty
              ? Text(
                  otherUserName.isNotEmpty
                      ? otherUserName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherUserName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lastTimestamp != null)
              Text(
                _formatTimestamp(lastTimestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                lastMessage.isEmpty ? 'لا توجد رسائل' : lastMessage,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).appBarTheme.backgroundColor,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatRoomScreen(
                chatId: chatId,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                otherUserImage: otherUserImage,
                currentUserId: _currentUserId, // تمرير معرف المالك
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // اليوم - عرض الوقت فقط
      return intl.DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} أيام';
    } else {
      return intl.DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }
}
