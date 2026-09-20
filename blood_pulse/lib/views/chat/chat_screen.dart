import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_center_wrapper.dart';
import '../../models/chat_message_model.dart';
import '../../services/chat_service.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';

/// 1-on-1 Real-Time Chat Screen
/// Rebuilt to precisely align with BloodPulse Stitch UI & WhatsApp read receipt convention:
/// - Light warm theme (#FAF7F7)
/// - Doctor / Donor Header with Online status & blood group badge
/// - Real person-to-person only: NO automated bots or simulated replies
/// - WhatsApp-style read receipts:
///     1. 'sent' -> Single grey tick
///     2. 'delivered' -> Double grey tick
///     3. 'read' -> Double cyan-blue tick (#34B7F1)
/// - Sender listens for status updates in real time via Firestore stream
/// - Full capsule input bar with paperclip, emoji, and red send button
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.chatRoomId = 'sarah_jenkins_o_minus',
    this.chatRecipientName = 'Sarah Jenkins',
    this.bloodGroup = 'O-',
    this.recipientId = 'sarah_jenkins',
  });

  final String chatRoomId;
  final String chatRecipientName;
  final String bloodGroup;
  final String recipientId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    // When screen initializes, notify that recipient is online/synced
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ??
          user?.primaryPhone ??
          'current_user';
      final currentUserName = user?.fullName.trim().isNotEmpty == true
          ? user!.fullName.trim()
          : (FirebaseAuth.instance.currentUser?.displayName ?? 'Blood Donor');

      ChatService.instance.createOrGetRoom(
        roomId: widget.chatRoomId,
        user1Id: currentUserId,
        user2Id: widget.recipientId,
        user1Name: currentUserName,
        user2Name: widget.chatRecipientName,
        bloodGroup: widget.bloodGroup,
      );

      ChatService.instance.markMessagesAsDelivered(widget.chatRoomId, currentUserId);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ??
        user?.primaryPhone ??
        'current_user';
    final currentUserName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : (FirebaseAuth.instance.currentUser?.displayName ?? 'Blood Donor');

    _textController.clear();
    setState(() => _showEmojiPicker = false);

    // Write real message to Firestore with status = 'sent' (single grey tick)
    await ChatService.instance.sendMessage(
      chatId: widget.chatRoomId,
      senderId: currentUserId,
      receiverId: widget.recipientId,
      text: text,
      senderName: currentUserName,
      receiverName: widget.chatRecipientName,
      bloodGroup: widget.bloodGroup,
    );

    _scrollToBottom();
  }

  void _handleAttachment() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.description_outlined, color: AppColors.primary),
              ),
              title: const Text('Hospital Report / Requisition Slip', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              subtitle: const Text('Attach PDF or requisition document', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document attachment selected.', style: TextStyle(fontFamily: 'Inter')),
                    backgroundColor: Color(0xFF1B8A4E),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.image_outlined, color: Colors.blue),
              ),
              title: const Text('Photo / ID Card', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              subtitle: const Text('Upload donor or patient photo', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Photo attachment selected.', style: TextStyle(fontFamily: 'Inter')),
                    backgroundColor: Color(0xFF1B8A4E),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ??
        user?.primaryPhone ??
        'current_user';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black.withAlpha(20),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2B2B2B), size: 22),
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
            // Avatar with Online Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                    color: const Color(0xFFFFECEF),
                  ),
                  child: Center(
                    child: Text(
                      widget.chatRecipientName.isNotEmpty
                          ? widget.chatRecipientName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Recipient Details
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
                      color: Color(0xFF222222),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Blood Group Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.bloodGroup,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Online',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF555555)),
            onSelected: (val) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Action: $val', style: const TextStyle(fontFamily: 'Inter')),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'profile', child: Text('View Donor Profile')),
              const PopupMenuItem(value: 'call', child: Text('Call Emergency Contact')),
              const PopupMenuItem(value: 'mute', child: Text('Mute Chat')),
              const PopupMenuItem(value: 'clear', child: Text('Clear History')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 720,
          child: Column(
            children: [
              // Real-Time Live Message Stream from Firestore
              Expanded(
                child: StreamBuilder<List<ChatMessageModel>>(
                  stream: ChatService.instance.getMessagesStream(
                    widget.chatRoomId,
                    currentUserId: currentUserId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }

                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty) {
                      return _buildEmptyState();
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent + 60,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == currentUserId;
                        return _buildMessageBubble(msg, isMe);
                      },
                    );
                  },
                ),
              ),

              // Emoji Quick Selector (Expandable)
              if (_showEmojiPicker) _buildEmojiPicker(),

              // Bottom Input Bar
              _buildBottomInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chat with ${widget.chatRecipientName}',
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coordinate voluntary blood donations securely and in real time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe) {
    final timeStr = DateFormat('h:mm a').format(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFFDE8EC) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              border: Border.all(
                color: isMe ? const Color(0xFFF9D1D8) : const Color(0xFFF0E5E5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              msg.text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.5,
                color: Color(0xFF222222),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _buildStatusTickIcon(msg.status, msg.isRead),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Strict WhatsApp tick convention:
  /// 1. 'sent' -> Single grey tick
  /// 2. 'delivered' -> Double grey tick
  /// 3. 'read' -> Double cyan-blue tick (#34B7F1)
  Widget _buildStatusTickIcon(String status, bool isRead) {
    if (status == 'read' || isRead) {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Color(0xFF34B7F1), // WhatsApp cyan blue
      );
    } else if (status == 'delivered') {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Color(0xFF8E8E93), // Double grey tick
      );
    } else {
      // 'sent' or default
      return const Icon(
        Icons.check,
        size: 14,
        color: Color(0xFF8E8E93), // Single grey tick
      );
    }
  }

  Widget _buildEmojiPicker() {
    final emojis = ['❤️', '🩸', '🙏', '👍', '😊', '🏥', '🙌', '💪', '🤝', '⏰'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: emojis.map((e) {
          return InkWell(
            onTap: () {
              _textController.text = _textController.text + e;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Input pill containing paperclip + text field + emoji
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6F6),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFFEADBDB), width: 1.2),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF6E6E6E), size: 20),
                    onPressed: _handleAttachment,
                    tooltip: 'Attach Document',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF222222),
                      ),
                      cursorColor: AppColors.primary,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF9E9E9E),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard_rounded : Icons.sentiment_satisfied_rounded,
                      color: const Color(0xFF6E6E6E),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                    tooltip: 'Emoji',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Red Circular Send Button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(70),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
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
