import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../widgets/message_bubble.dart';

/// شاشة غرفة المحادثة
class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;
  final String? currentUserId; // إضافة معامل اختياري لمعرف المستخدم الحالي

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
    this.currentUserId, // اختياري للمالك
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final StorageService _storageService = StorageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _currentUserId;
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // عندما يعود المستخدم للتطبيق، قم بتحديث حالة القراءة
    if (state == AppLifecycleState.resumed && _currentUserId != null) {
      _chatService.markMessagesAsRead(
        chatId: widget.chatId,
        userId: _currentUserId!,
      );
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      // إذا تم تمرير currentUserId، استخدمه مباشرة
      if (widget.currentUserId != null) {
        setState(() {
          _currentUserId = widget.currentUserId;
        });
        // تمييز الرسائل كمقروءة
        await _chatService.markMessagesAsRead(
          chatId: widget.chatId,
          userId: _currentUserId!,
        );
        return;
      }

      // وإلا حمّله من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId =
          prefs.getString('currentUserId') ?? prefs.getString('user_phone');

      setState(() {
        _currentUserId = userId;
      });

      if (_currentUserId != null) {
        // تمييز الرسائل كمقروءة
        await _chatService.markMessagesAsRead(
          chatId: widget.chatId,
          userId: _currentUserId!,
        );
      }
    } catch (e) {
      print('❌ خطأ في تحميل معرف المستخدم: $e');
      setState(() {}); // تحديث الواجهة حتى في حالة الخطأ
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({
    String? text,
    MessageType type = MessageType.text,
    String? imageUrl,
    Map<String, dynamic>? location,
  }) async {
    if (_currentUserId == null) return;

    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty && type == MessageType.text) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: _currentUserId!,
        text: messageText,
        type: type,
        imageUrl: imageUrl,
        location: location,
      );

      _messageController.clear();

      // التمرير للأسفل
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في إرسال الرسالة: $e')));
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final imageUrl = await _storageService.uploadImage(
        imageFile: File(image.path),
        chatId: widget.chatId,
        senderId: _currentUserId!,
      );

      if (imageUrl != null) {
        await _sendMessage(
          text: '📷 صورة',
          type: MessageType.image,
          imageUrl: imageUrl,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في إرسال الصورة: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendLocation() async {
    try {
      setState(() => _isLoading = true);

      // التحقق من الأذونات
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'تم رفض أذونات الموقع';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'أذونات الموقع مرفوضة بشكل دائم';
      }

      // الحصول على الموقع الحالي
      final position = await Geolocator.getCurrentPosition();

      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _sendMessage(
        text: '📍 موقع',
        type: MessageType.location,
        location: locationData,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في إرسال الموقع: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFF2B0606)),
              title: const Text('إرسال صورة'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFF2B0606)),
              title: const Text('إرسال موقع'),
              onTap: () {
                Navigator.pop(context);
                _sendLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              backgroundImage: widget.otherUserImage != null
                  ? NetworkImage(widget.otherUserImage!)
                  : null,
              child: widget.otherUserImage == null
                  ? Text(
                      widget.otherUserName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // قائمة الرسائل
          Expanded(
            child: _currentUserId == null
                ? const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : StreamBuilder<List<Message>>(
                    stream: _chatService.getMessages(widget.chatId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('خطأ: ${snapshot.error}'));
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // تحذير مراقبة المحادثات
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6E1229,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF6E1229,
                                    ).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 56,
                                      color: const Color(0xFF6E1229),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'كل المحادثات مراقبة من قبل الإدارة',
                                      style: TextStyle(
                                        color: const Color(0xFF6E1229),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد رسائل بعد',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ابدأ المحادثة الآن',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        cacheExtent: 200,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == _currentUserId;

                          return MessageBubble(
                            message: message,
                            isMe: isMe,
                            onDelete: () => _deleteMessage(message.id),
                          );
                        },
                      );
                    },
                  ),
          ),

          // شريط الإدخال
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: Colors.black12,
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _showOptionsMenu,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة',
                      hintTextDirection: TextDirection.rtl,
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).appBarTheme.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _chatService.deleteMessage(
        chatId: widget.chatId,
        messageId: messageId,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في حذف الرسالة: $e')));
    }
  }
}
