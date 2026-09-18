import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_center_wrapper.dart';

/// Data model representing an in-chat message or appointment card.
class ChatMessageItem {
  final String id;
  final bool isMe;
  final String text;
  final String time;
  final bool isDelivered;
  final bool isCard;
  final String? cardTitle;
  final String? cardSubtitle;
  final String? hospital;
  final String? room;

  const ChatMessageItem({
    required this.id,
    this.isMe = false,
    this.text = '',
    required this.time,
    this.isDelivered = true,
    this.isCard = false,
    this.cardTitle,
    this.cardSubtitle,
    this.hospital,
    this.room,
  });
}

/// 1-on-1 Interactive Real-Time Chat Screen
/// Rebuilt to precisely align with the reference mockup:
/// - Light warm theme (#FAF7F7)
/// - Doctor / Donor Header with Online status & blood group badge
/// - Pre-seeded authentic conversation matching reference
/// - Interactive 'Appointment Confirmed' card with view modal
/// - Full capsule input bar with paperclip, emoji, and red send button
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.chatRoomId = 'sarah_jenkins_o_minus',
    this.chatRecipientName = 'Sarah Jenkins',
    this.bloodGroup = 'O-',
  });

  final String chatRoomId;
  final String chatRecipientName;
  final String bloodGroup;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showEmojiPicker = false;

  late List<ChatMessageItem> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [
      const ChatMessageItem(
        id: '1',
        isMe: false,
        text: 'request for O- blood at Central General. Is the donation slot still open for 3 PM?',
        time: '10:45 AM',
      ),
      const ChatMessageItem(
        id: '2',
        isMe: true,
        text: 'Hi Sarah! Yes, the slot is still open. We really appreciate you reaching out so quickly. The patient is undergoing surgery tomorrow.',
        time: '10:47 AM',
        isDelivered: true,
      ),
      const ChatMessageItem(
        id: '3',
        isMe: false,
        text: "Understood. I've just confirmed the appointment through the BloodPulse app. I'll make sure to hydrate and have a good meal beforehand.",
        time: '10:48 AM',
      ),
      const ChatMessageItem(
        id: '4',
        isCard: true,
        cardTitle: 'Appointment Confirmed',
        cardSubtitle: 'Central General Hospital • Room 402',
        hospital: 'Central General Hospital',
        room: 'Room 402, Blood Bank & Transfusion Wing',
        time: '10:48 AM',
      ),
      const ChatMessageItem(
        id: '5',
        isMe: true,
        text: "Perfect! Please bring your ID. I'll be there to meet you at the reception. See you then!",
        time: '10:49 AM',
        isDelivered: true,
      ),
    ];
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

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final nowTime = DateFormat('h:mm a').format(DateTime.now());
    final newMsg = ChatMessageItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isMe: true,
      text: text,
      time: nowTime,
      isDelivered: true,
    );

    setState(() {
      _messages.add(newMsg);
      _textController.clear();
      _showEmojiPicker = false;
    });

    _scrollToBottom();

    // Friendly automated donor response simulation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final replyTime = DateFormat('h:mm a').format(DateTime.now());
        setState(() {
          _messages.add(
            ChatMessageItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              isMe: false,
              text: "Got it! See you at 3:00 PM. I'm ready to donate.",
              time: replyTime,
            ),
          );
        });
        _scrollToBottom();
      }
    });
  }

  void _showAppointmentDetails(ChatMessageItem item) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE5E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emergency_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appointment Confirmed',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Verified Voluntary Blood Donor Slot',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow(Icons.local_hospital_outlined, 'Hospital', item.hospital ?? 'Central General Hospital'),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.meeting_room_outlined, 'Location', item.room ?? 'Room 402, Blood Bank & Transfusion Wing'),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.access_time_rounded, 'Slot Time', 'Today at 3:00 PM'),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.bloodtype_outlined, 'Blood Needed', '${widget.bloodGroup} Negative'),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.person_outline_rounded, 'Donor', widget.chatRecipientName),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          '$title: ',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF111111)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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
              // Message Stream List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final item = _messages[index];
                    if (item.isCard) {
                      return _buildAppointmentCard(item);
                    }
                    return _buildMessageBubble(item);
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

  Widget _buildMessageBubble(ChatMessageItem msg) {
    final isMe = msg.isMe;

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
                msg.time,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.done_all_rounded,
                  size: 14,
                  color: Color(0xFF3584E4),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(ChatMessageItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0E4E4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pink Circle with Red Asterisk/Medical Cross
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE5E8),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '✱',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.cardTitle ?? 'Appointment Confirmed',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.cardSubtitle ?? 'Central General Hospital • Room 402',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: Color(0xFF6E6E6E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Red Capsule "View" Button
            ElevatedButton(
              onPressed: () => _showAppointmentDetails(item),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
