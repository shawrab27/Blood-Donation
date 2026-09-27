// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/assistant_provider.dart';
import '../../domain/models/assistant_message_model.dart';
import '../../../../widgets/pulse_loading_indicator.dart';
import 'dart:math' as math;

class AssistantScreen extends ConsumerStatefulWidget {
  final String? screenContext;
  const AssistantScreen({Key? key, this.screenContext}) : super(key: key);

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _firstRunHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstRun();

    });
  }

  void _checkFirstRun() {
    final state = ref.read(assistantProvider);
    if (state.isFirstRun && !_firstRunHandled) {
      _firstRunHandled = true;
      _showConsentSheet();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showConsentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const ConsentSheetWidget(),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    ref.read(assistantProvider.notifier).sendMessage(text, 'en', screenContext: widget.screenContext);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    
    ref.listen<AssistantState>(assistantProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
      if (next.isFirstRun && !_firstRunHandled) {
        _firstRunHandled = true;
        Future.delayed(Duration.zero, _showConsentSheet);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFDF3F3), // Light pink background matching mockup
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/pulse_ai_icon.png',
          width: 32,
          height: 32,
          errorBuilder: (_, _, _) => const Icon(
            Icons.smart_toy_outlined,
            size: 28,
            color: Color(0xFFC30121),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Pinned Banner
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Flexible(child: Text("AI-assisted guidance — not a medical diagnosis. Always consult a doctor.", overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey))),
                  ],
                ),
              ),
            ),
            
            // Messages Area
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: state.isLoading && state.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFC30121)))
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.messages.length + (state.isSending ? 1 : 0) + 1,
                        itemBuilder: (context, index) {
                          if (index == 0 && state.isSending) return const TypingIndicator();
                          
                          final messageIndex = state.messages.length - 1 - (index - (state.isSending ? 1 : 0));
                          
                          if (messageIndex < 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 24, top: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.white,
                                    backgroundImage: const AssetImage('assets/images/pulse_ai_icon.png'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _AssistantBubble(
                                      text: "Hello! I'm **PulseAI**, your clinical companion for transfusion medicine, donation deferrals, lab diagnostics, and emergency donor mobilization.\n\nHow can I assist you with your donation or clinical inquiries today?",
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          final message = state.messages[messageIndex];
                          return MessageWidget(message: message);
                        },
                      ),
                ),
              ),
            ),
            
            // Quick Actions & Input Bar
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFDF3F3),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: [
                  // Quick Actions above input bar
                  if (state.quickActions.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: state.quickActions.map((q) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(q.textEn, style: const TextStyle(fontSize: 12, color: Color(0xFF2B2B2B))),
                            onPressed: () => _sendMessage(q.textEn),
                            backgroundColor: const Color(0xFFF3DDE0),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )).toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Input Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 4,
                            enabled: !state.isSending,
                            decoration: const InputDecoration(
                              hintText: "Ask PulseAI or paste lab results...",
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                              border: InputBorder.none,
                              counterText: "",
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: _sendMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.mic_none_outlined, color: Colors.grey),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _textController,
                          builder: (context, value, child) {
                            final canSend = value.text.trim().isNotEmpty && !state.isSending;
                            return Container(
                              decoration: BoxDecoration(
                                color: canSend ? const Color(0xFFC30121) : Colors.grey.shade300,
                                shape: BoxShape.circle,
                              ),
                              margin: const EdgeInsets.only(bottom: 2),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                                onPressed: canSend ? () => _sendMessage(_textController.text) : null,
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 10, color: Colors.grey),
                      SizedBox(width: 4),
                      Flexible(child: Text("End-to-end encrypted clinical triage session", overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.grey))),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageWidget extends ConsumerWidget {
  final AssistantMessage message;

  const MessageWidget({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFC30121), // Fixed Deep Red instead of Dark Crimson
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            backgroundImage: const AssetImage('assets/images/pulse_ai_icon.png'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AssistantBubble(text: message.text),
                
                if (message.actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: message.actions.map((action) => ActionChip(
                        label: Text(action.labelEn, style: const TextStyle(color: Color(0xFFC30121))),
                        onPressed: () {
                          if (action.route.isNotEmpty) context.push(action.route);
                        },
                        backgroundColor: const Color(0xFFC30121).withOpacity(0.1),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      )).toList(),
                    ),
                  ),
                  
                if (message.emergency)
                  const EmergencyCard(),
                  
                if (message.needsHuman || message.hasThumbsDown)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: const Text("Talk to a human"),
                      onPressed: () {
                        showDialog(context: context, builder: (_) => const HandoffDialog());
                      },
                    ),
                  ),

                // Feedback (hidden in production typically unless hovered, but we show it small)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => ref.read(assistantProvider.notifier).sendFeedback(message, 'UP'),
                        child: const Icon(Icons.thumb_up_alt_outlined, size: 14, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          ref.read(assistantProvider.notifier).sendFeedback(message, 'DOWN');
                        },
                        child: Icon(Icons.thumb_down_alt_outlined, size: 14, color: message.hasThumbsDown ? Colors.red : Colors.grey),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String text;
  const _AssistantBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SelectableText(
        text.replaceAll('**', ''), // A poor man's markdown stripper just to make it clean if needed, ideally use flutter_markdown. 
        style: const TextStyle(color: Color(0xFF2B2B2B), fontSize: 14, height: 1.4),
      ),
    );
  }
}

class EmergencyCard extends StatelessWidget {
  const EmergencyCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3DDE0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFC30121), size: 16),
              SizedBox(width: 8),
              Text("EMERGENCY ACTIONS", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC30121), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:999')),
              icon: const Icon(Icons.call, color: Colors.white, size: 16),
              label: const Text("Call 999", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC30121), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/emergency-request'),
              child: const Text("Request Emergency Blood"),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC30121), side: const BorderSide(color: Color(0xFFC30121)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            ),
          )
        ],
      ),
    );
  }
}

// Dialogs and indicators are same
class ConsentSheetWidget extends ConsumerWidget {
  const ConsentSheetWidget({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BloodPulse Assistant Privacy", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text("The assistant uses AI to help answer your questions. Please do not share any personal health information or phone numbers."),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(assistantProvider.notifier).saveConsent(true);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC30121), foregroundColor: Colors.white),
              child: const Text("Accept & Continue"),
            ),
          )
        ],
      ),
    );
  }
}

class HandoffDialog extends ConsumerStatefulWidget {
  const HandoffDialog({Key? key}) : super(key: key);
  @override
  ConsumerState<HandoffDialog> createState() => _HandoffDialogState();
}
class _HandoffDialogState extends ConsumerState<HandoffDialog> {
  final _subjectCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _pref = 'IN_APP';
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Talk to a human"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: "Subject")),
            const SizedBox(height: 16),
            TextField(controller: _msgCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Message")),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            ref.read(assistantProvider.notifier).submitHandoff(_subjectCtrl.text, _msgCtrl.text, _pref);
            Navigator.pop(context);
          },
          child: const Text("Submit"),
        )
      ],
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white,
          backgroundImage: AssetImage('assets/images/pulse_ai_icon.png'),
        ),
        SizedBox(width: 8),
        PulseLoadingIndicator(
          color: Color(0xFFC30121),
          backgroundColor: Color(0xFFFDF3F3),
        ),
      ],
    );
  }
}
