import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatelessWidget {
  final String currentUserId;
  final String userType; // 'user' | 'vendor' | 'admin'

  const ChatsListScreen({required this.currentUserId, required this.userType, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('المحادثات')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .orderBy('lastTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final chats = snapshot.data!.docs;
          if (chats.isEmpty) return Center(child: Text('لا توجد محادثات'));
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherId = (chat['participants'] as List).firstWhere((id) => id != currentUserId);
              return ListTile(
                title: Text('محادثة مع: $otherId'),
                subtitle: Text(chat['lastMessage'] ?? ''),
                trailing: Text(_formatTime(chat['lastTime'])),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(chatId: chat.id, currentUserId: currentUserId),
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
