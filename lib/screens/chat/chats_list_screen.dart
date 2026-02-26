import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat_room_screen.dart';

class ChatsListScreen extends StatelessWidget {
  final String currentUserId;
  final String userType; // 'user' | 'vendor' | 'admin'

  const ChatsListScreen({
    required this.currentUserId,
    required this.userType,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        centerTitle: true,
        title: const Text(
          'المحادثات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          // ترتيب من جانب العميل
          final chats = snapshot.data!.docs;
          chats.sort((a, b) {
            final aTime = a['lastTime'] as Timestamp?;
            final bTime = b['lastTime'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (chats.isEmpty) return Center(child: Text('لا توجد محادثات'));
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherId = (chat['participants'] as List).firstWhere(
                (id) => id != currentUserId,
              );
              return ListTile(
                title: Text('محادثة مع: $otherId'),
                subtitle: Text(chat['lastMessage'] ?? ''),
                trailing: Text(_formatTime(chat['lastTime'])),
                onTap: () {
                  // تحديد الاسم المعروض
                  String displayName = otherId;
                  if (otherId == '07721874360') {
                    displayName = 'الدعم الفني';
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        chatId: chat.id,
                        currentUserId: currentUserId,
                        otherUserId: otherId,
                        otherUserName: displayName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(Timestamp ts) {
    final dt = ts.toDate();
    return '${dt.hour}:${dt.minute}';
  }
}
