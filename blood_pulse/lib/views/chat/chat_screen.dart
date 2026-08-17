import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/blood_pulse_app_bar.dart';
import '../../core/widgets/shimmer_loading_widget.dart';
import '../../models/chat_message_model.dart';
import '../../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.chatId = 'chat_999',
    this.recipientName = 'Dr. Alim (DMCH Transfusion)',
    this.recipientBloodGroup = 'O+',
    this.currentUserId = 'usr_101',
  });

  final String chatId;
  final String recipientName;
  final String recipientBloodGroup;
  final String currentUserId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-Mark incoming messages as read upon screen view
    ChatService.instance.markAllAsRead(widget.chatId, widget.currentUserId);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _onSendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    ChatService.instance.sendMessage(
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      receiverId: 'req_202',
      text: text,
    );

    _msgCtrl.clear();
  }

  void _showAttachmentPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Attach Medical Report or Map', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachOption(Icons.description_outlined, 'Prescription Report', AppColors.primary, () {
                  ChatService.instance.sendMessage(
                    chatId: widget.chatId,
                    senderId: widget.currentUserId,
                    receiverId: 'req_202',
                    text: 'Attached verified medical report.',
                    attachmentUrl: 'https://bloodpulse.org/reports/Verified_Prescription.pdf',
                  );
                }),
                _attachOption(Icons.location_on_outlined, 'Hospital Map', AppColors.tertiary, () {
                  ChatService.instance.sendMessage(
                    chatId: widget.chatId,
                    senderId: widget.currentUserId,
                    receiverId: 'req_202',
                    text: 'Shared DMCH Transfusion Gate 2 Location.',
                    attachmentUrl: 'https://maps.google.com/?q=DMCH',
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attached $label to emergency thread!'), backgroundColor: color, behavior: SnackBarBehavior.floating),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Emergency Chat Desk',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveLayout(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Recipient Header
            _buildChatHeader(),

            // Real-Time Stream Message Thread View
            Expanded(
              child: Container(
                color: const Color(0xFFFAF6F6),
                child: StreamBuilder<List<ChatMessageModel>>(
                  stream: ChatService.instance.getMessagesStream(
                    widget.chatId,
                    currentUserId: widget.currentUserId,
                  ),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: 4,
                        itemBuilder: (c, i) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: ShimmerLoadingWidget(height: 60, borderRadius: 16),
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: messages.length,
                      itemBuilder: (ctx, idx) => _buildMessageBubble(messages[idx]),
                    );
                  },
                ),
              ),
            ),

            // WhatsApp-Style Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFF3DDE0),
                child: Text(
                  widget.recipientName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.recipientName, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFFF0F1), borderRadius: BorderRadius.circular(50)),
                      child: Text(widget.recipientBloodGroup, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
                const Text('Online • Active Emergency Desk', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.success)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📞 Dialing emergency requester phone...'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final isMe = msg.senderId == widget.currentUserId;
    final timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFFFF0F1) : Colors.white, // Sent: Light red tint (#FFF0F1)
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(color: isMe ? const Color(0xFFE6BDBA) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.attachmentUrl != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withAlpha(50))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(msg.attachmentUrl!.split('/').last, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ],
            Text(
              msg.text,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary, height: 1.4),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(timeStr, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.neutral)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded, // Double blue tick read receipt
                    size: 14,
                    color: msg.isRead ? AppColors.tertiary : AppColors.neutral,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: AppColors.neutral),
            onPressed: _showAttachmentPicker,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF3F3),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(fontFamily: 'Inter', color: AppColors.neutral, fontSize: 13),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _onSendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _onSendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
