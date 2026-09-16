import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/responsive_center_wrapper.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';

/// 1-on-1 Real-time Chat powered by Firebase Firestore.
/// Enforces dark surface theme `#271816` with minimal latency rendering.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.chatRoomId = 'general_emergency',
    this.chatRecipientName = 'Emergency Responder',
  });

  final String chatRoomId;
  final String chatRecipientName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isComposing = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _resolveCurrentUserId() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      if (user.primaryPhone.isNotEmpty) return user.primaryPhone;
      if (user.email.isNotEmpty) return user.email;
    }
    return 'guest_donor';
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = _resolveCurrentUserId();

    // 1. Immediately clear the input field for zero-perceived-latency
    _textController.clear();
    setState(() => _isComposing = false);

    // 2. Insert document directly to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatRoomId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (err) {
      debugPrint('[ChatScreen] Error sending message: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message failed to send: $err', style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: const Color(0xFFC30121),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _resolveCurrentUserId();

    return Scaffold(
      backgroundColor: const Color(0xFF271816), // Dark surface theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1211),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/feed');
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0x33C30121),
                  child: Text(
                    widget.chatRecipientName.isNotEmpty
                        ? widget.chatRecipientName.substring(0, 1).toUpperCase()
                        : 'R',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B8A4E),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1F1211), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.chatRecipientName,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Active Now • End-to-end encrypted',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0x99FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xB3FFFFFF), size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Chat Room: ${widget.chatRoomId}', style: const TextStyle(fontFamily: 'Inter')),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 700,
          child: Column(
            children: [
              // ── Message Stream List ──
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatRoomId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Failed to load messages: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Inter', color: Color(0xB3FFFFFF), fontSize: 13),
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFC30121),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0x14FFFFFF),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0x73FFFFFF), size: 36),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Start the Conversation',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Coordinate blood donation logistics instantly.',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0x8CFFFFFF)),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Newest messages at bottom
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final senderId = data['senderId'] as String? ?? '';
                        final text = data['text'] as String? ?? '';
                        final timestamp = data['timestamp'] as Timestamp?;
                        final isMe = senderId == currentUserId;

                        return _MessageBubble(
                          text: text,
                          isMe: isMe,
                          timestamp: timestamp?.toDate(),
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Message Input Bar ──
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1211),
        border: Border(
          top: BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 14),
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (val) {
                  final isWriting = val.trim().isNotEmpty;
                  if (isWriting != _isComposing) {
                    setState(() => _isComposing = isWriting);
                  }
                },
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(fontFamily: 'Inter', color: Color(0x66FFFFFF), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: _isComposing ? _sendMessage : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isComposing
                      ? const LinearGradient(
                          colors: [Color(0xFFC30121), Color(0xFF9E001A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _isComposing ? null : const Color(0x14FFFFFF),
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _isComposing ? Colors.white : const Color(0x4DFFFFFF),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal latency rendering message bubble.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isMe,
    this.timestamp,
  });

  final String text;
  final bool isMe;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final timeString = timestamp != null ? DateFormat('hh:mm a').format(timestamp!) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFFC30121), Color(0xFF9E001A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : const Color(0x1AFFFFFF), // Glassy dark background for recipient
                border: isMe ? null : Border.all(color: const Color(0x1FFFFFFF), width: 1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: isMe
                    ? const [
                        BoxShadow(
                          color: Color(0x33C30121),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                  if (timeString.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      timeString,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: isMe ? const Color(0xB3FFFFFF) : const Color(0x73FFFFFF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
