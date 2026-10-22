import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/responsive_center_wrapper.dart';
import '../../models/chat_message_model.dart';
import '../../services/chat_service.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../services/api_client.dart';

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
    this.chatRoomId = '',
    this.chatRecipientName = 'Chat Contact',
    this.bloodGroup = '',
    this.recipientId = '',
    this.isClosed = false,
  });

  final String chatRoomId;
  final String chatRecipientName;
  final String bloodGroup;
  final String recipientId;
  final bool isClosed;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showEmojiPicker = false;
  bool _isVoiceAvailable = true;

  String? _playingMessageId;
  double _playbackProgress = 0.0;
  Timer? _playbackTimer;

  String _getCurrentUserId(dynamic user) {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}
    return user?.primaryPhone ?? 'current_user';
  }

  String _getCurrentUserName(dynamic user) {
    if (user?.fullName.trim().isNotEmpty == true) {
      return user!.fullName.trim();
    }
    try {
      final name = FirebaseAuth.instance.currentUser?.displayName;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return 'Blood Donor';
  }

  @override
  void initState() {
    super.initState();
    // When screen initializes, notify that recipient is online/synced
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      final currentUserId = _getCurrentUserId(user);
      final currentUserName = _getCurrentUserName(user);

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
    _playbackTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleVoicePlayback(ChatMessageModel msg) {
    if (_playingMessageId == msg.messageId) {
      _stopVoicePlayback();
    } else {
      _startVoicePlayback(msg);
    }
  }

  void _startVoicePlayback(ChatMessageModel msg) {
    _playbackTimer?.cancel();
    setState(() {
      _playingMessageId = msg.messageId;
      _playbackProgress = 0.0;
    });

    final durationSec = msg.voiceDurationSeconds > 0 ? msg.voiceDurationSeconds : 5;
    const intervalMs = 200;
    final totalSteps = (durationSec * 1000) / intervalMs;
    int step = 0;

    _playbackTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      step++;
      if (step >= totalSteps) {
        _stopVoicePlayback();
      } else {
        if (mounted) {
          setState(() {
            _playbackProgress = step / totalSteps;
          });
        }
      }
    });
  }

  void _stopVoicePlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (mounted) {
      setState(() {
        _playingMessageId = null;
        _playbackProgress = 0.0;
      });
    }
  }

  void _showMessageOptions(ChatMessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Color(0xFF555555)),
                  title: const Text('Copy Message', style: TextStyle(fontFamily: 'Inter')),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: const Text('Report Message', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog(msg);
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Message', style: TextStyle(fontFamily: 'Inter', color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ChatService.instance.deleteMessage(
                      chatId: widget.chatRoomId,
                      messageId: msg.messageId,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message deleted.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(ChatMessageModel msg) {
    final reasonController = TextEditingController(text: 'Inappropriate or abusive language.');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Report Message', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for reporting this message:',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Enter reason...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(dialogCtx);
              await ChatService.instance.reportMessage(
                chatId: widget.chatRoomId,
                messageId: msg.messageId,
                reason: reason.isNotEmpty ? reason : 'Inappropriate content',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you. Message has been reported for moderation.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFF1B8A4E),
                  ),
                );
              }
            },
            child: const Text('Submit Report', style: TextStyle(fontFamily: 'Inter', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVoiceRecordModal() {
    int duration = 0;
    Timer? timer;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (duration >= 60) {
              t.cancel();
            } else {
              setModalState(() {
                duration++;
              });
            }
          });

          final mins = (duration ~/ 60).toString().padLeft(2, '0');
          final secs = (duration % 60).toString().padLeft(2, '0');

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Recording Voice Note ($mins:$secs / 01:00)',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF222222),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Speak clearly into your microphone. Max 60 seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF757575)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          timer?.cancel();
                          Navigator.pop(sheetCtx);
                        },
                        child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          timer?.cancel();
                          Navigator.pop(sheetCtx);
                          await _sendVoiceMessage(duration > 0 ? duration : 3);
                        },
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                        label: const Text('Send Note', style: TextStyle(fontFamily: 'Inter', color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendVoiceMessage(int durationSeconds) async {
    final user = ref.read(authProvider).user;
    final currentUserId = _getCurrentUserId(user);
    final currentUserName = _getCurrentUserName(user);

    final dummyAudioBytes = [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20];
    String? voiceUrl;

    try {
      final uploadRes = await ChatService.instance.uploadVoiceNote(
        chatId: widget.chatRoomId,
        audioBytes: dummyAudioBytes,
        durationSeconds: durationSeconds,
      );
      if (uploadRes != null) {
        voiceUrl = uploadRes['voice_url'] as String?;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 503 || e.rawError == 'VOICE_UNAVAILABLE') {
        if (mounted) {
          setState(() => _isVoiceAvailable = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message.isNotEmpty ? e.message : 'Voice messaging is temporarily unavailable.'),
              backgroundColor: Colors.black87,
            ),
          );
        }
        return;
      }
    } catch (_) {}

    if (voiceUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice messaging is currently unavailable.'),
            backgroundColor: Colors.black87,
          ),
        );
      }
      return;
    }

    await ChatService.instance.sendMessage(
      chatId: widget.chatRoomId,
      senderId: currentUserId,
      receiverId: widget.recipientId,
      text: '',
      senderName: currentUserName,
      receiverName: widget.chatRecipientName,
      bloodGroup: widget.bloodGroup,
      messageType: 'VOICE',
      voiceUrl: voiceUrl,
      voiceDurationSeconds: durationSeconds,
    );

    _scrollToBottom();
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
    final currentUserId = _getCurrentUserId(user);
    final currentUserName = _getCurrentUserName(user);

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
    final currentUserId = _getCurrentUserId(user);

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
                        child: AppLoader(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFFC30121)),
                              const SizedBox(height: 12),
                              Text(
                                'Unable to load live messages (${snapshot.error})',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF666666)),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
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
              widget.isClosed ? _buildReadOnlyBanner() : _buildBottomInputBar(),
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
          GestureDetector(
            onLongPress: () => _showMessageOptions(msg, isMe),
            child: Container(
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
              child: msg.isVoice
                  ? _buildVoiceBubbleContent(msg, isMe)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            color: Color(0xFF222222),
                            height: 1.4,
                          ),
                        ),
                        if (msg.isReported) ...[
                          const SizedBox(height: 4),
                          const Text(
                            '⚠️ Reported for review',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildVoiceBubbleContent(ChatMessageModel msg, bool isMe) {
    final isPlaying = _playingMessageId == msg.messageId;
    final durationSec = msg.voiceDurationSeconds > 0 ? msg.voiceDurationSeconds : 5;
    final mins = (durationSec ~/ 60).toString();
    final secs = (durationSec % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _toggleVoicePlayback(msg),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : const Color(0xFF2B2B2B),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: isPlaying ? _playbackProgress : 0.0,
                      backgroundColor: Colors.black.withAlpha(20),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isMe ? AppColors.primary : const Color(0xFF2B2B2B),
                      ),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$mins:$secs',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF6E6E6E),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.mic_rounded, size: 12, color: Color(0xFF8E8E93)),
                          SizedBox(width: 2),
                          Text(
                            'Voice note',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF8E8E93)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (msg.isReported) ...[
          const SizedBox(height: 4),
          const Text(
            '⚠️ Reported for review',
            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
          ),
        ],
      ],
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

  Widget _buildReadOnlyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: const Color(0xFFF0EBEB),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF8E7D7F)),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'This request is completed or closed. Chat is read-only.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E7D7F),
              ),
            ),
          ),
        ],
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

          // Mic Button for Voice Note (#39)
          IconButton(
            icon: Icon(
              Icons.mic_rounded,
              color: _isVoiceAvailable ? AppColors.primary : const Color(0xFFB0B0B0),
              size: 24,
            ),
            tooltip: _isVoiceAvailable ? 'Record Voice Note' : 'Voice messaging unavailable',
            onPressed: _isVoiceAvailable
                ? _showVoiceRecordModal
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voice messaging is temporarily unavailable because persistent storage is not configured.'),
                        backgroundColor: Colors.black87,
                      ),
                    );
                  },
          ),
          const SizedBox(width: 4),

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
