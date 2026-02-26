import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

/// فقاعة الرسالة
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete != null
          ? () => _showMessageOptions(context)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFF2B0606)
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // محتوى الرسالة حسب النوع
                    _buildMessageContent(),
                    
                    const SizedBox(height: 4),
                    
                    // الوقت وحالة القراءة
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe
                                ? Colors.white70
                                : Colors.grey[600],
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.readBy.length > 1
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color: message.readBy.length > 1
                                ? Colors.blue[300]
                                : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (message.type) {
      case MessageType.image:
        return _buildImageMessage();
      case MessageType.location:
        return _buildLocationMessage();
      case MessageType.audio:
        return _buildAudioMessage();
      case MessageType.file:
        return _buildFileMessage();
      default:
        return _buildTextMessage();
    }
  }

  Widget _buildTextMessage() {
    return SelectableText(
      message.text,
      style: TextStyle(
        fontSize: 15,
        color: isMe ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildImageMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              message.imageUrl!,
              width: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                );
              },
            ),
          ),
        if (message.text.isNotEmpty && message.text != '📷 صورة')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationMessage() {
    final location = message.location;
    if (location == null) return const Text('موقع غير صالح');

    final lat = location['latitude'];
    final lng = location['longitude'];

    return GestureDetector(
      onTap: () => _openMap(lat, lng),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: isMe ? Colors.white : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'موقع مشترك',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'اضغط لفتح الخريطة',
              style: TextStyle(
                fontSize: 13,
                color: isMe ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioMessage() {
    return Row(
      children: [
        Icon(
          Icons.play_circle_filled,
          color: isMe ? Colors.white : const Color(0xFF2B0606),
          size: 32,
        ),
        const SizedBox(width: 8),
        Text(
          '${message.audioDuration ?? 0}s',
          style: TextStyle(
            fontSize: 14,
            color: isMe ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildFileMessage() {
    return Row(
      children: [
        Icon(
          Icons.insert_drive_file,
          color: isMe ? Colors.white : const Color(0xFF2B0606),
          size: 32,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message.fileName ?? 'ملف',
            style: TextStyle(
              fontSize: 14,
              color: isMe ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime timestamp) {
    return intl.DateFormat('HH:mm').format(timestamp);
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف الرسالة'),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
