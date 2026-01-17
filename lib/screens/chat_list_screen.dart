import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';

/// Screen showing list of all chat conversations
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseService _firebase = FirebaseService.instance;

  String? get _currentUserId => _firebase.auth.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Chat>>(
        stream: _chatService.getChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start a safe journey or request\nan escort to begin chatting',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _buildChatTile(chat);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatTile(Chat chat) {
    final otherName = chat.getOtherParticipantName(_currentUserId ?? '');
    final unreadCount = chat.getUnreadCount(_currentUserId ?? '');
    final lastMessage = chat.lastMessage;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE91E63),
            radius: 24,
            child: Text(
              otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        otherName,
        style: TextStyle(
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: lastMessage != null
          ? Row(
              children: [
                if (lastMessage.type == MessageType.location)
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                if (lastMessage.type == MessageType.sos)
                  const Icon(Icons.warning, size: 16, color: Colors.red),
                Expanded(
                  child: Text(
                    _getLastMessagePreview(lastMessage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unreadCount > 0 ? Colors.black87 : Colors.grey,
                      fontWeight:
                          unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            )
          : const Text('No messages yet'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat.updatedAt),
            style: TextStyle(
              fontSize: 12,
              color: unreadCount > 0 ? const Color(0xFFE91E63) : Colors.grey,
            ),
          ),
          if (chat.escortRequestId != null || chat.trackingSessionId != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Active',
                style: TextStyle(fontSize: 10, color: Colors.green),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chat.id,
              otherUserName: otherName,
              otherUserId: chat.getOtherParticipantId(_currentUserId ?? ''),
            ),
          ),
        );
      },
      onLongPress: () => _showChatOptions(chat),
    );
  }

  String _getLastMessagePreview(Message message) {
    switch (message.type) {
      case MessageType.location:
        return 'Shared location';
      case MessageType.sos:
        return 'SOS Alert!';
      case MessageType.system:
        return message.content;
      case MessageType.image:
        return 'Photo';
      case MessageType.text:
      default:
        return message.content;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  void _showChatOptions(Chat chat) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Chat'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Chat?'),
                    content: const Text(
                      'This will delete all messages in this conversation.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _chatService.deleteChat(chat.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
