import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/assistant_provider.dart';
import '../../data/assistant_api_service.dart';
import '../../domain/models/assistant_message_model.dart';
import '../../../../widgets/pulse_loading_indicator.dart';
import '../../../../core/widgets/avatar_helper.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import 'package:flutter/foundation.dart';
import '../../data/pulseai_audio_service.dart';
import '../widgets/ecg_3d_background.dart';
import '../../../../core/theme/app_colors.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  final String? screenContext;
  const AssistantScreen({Key? key, this.screenContext}) : super(key: key);

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _firstRunHandled = false;
  bool _isListening = false;
  String? _voiceNotice;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstRun();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voice input is not supported on web.")),
      );
      return;
    }

    if (_isListening) {
      await PulseAIAudioService.instance.stopListening();
      setState(() => _isListening = false);
      return;
    }

    // Show one-line notice once about speech recognition using device speech service
    if (_voiceNotice == null) {
      _voiceNotice = "Speech recognition uses device speech service. Redaction runs before sending.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_voiceNotice!),
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF2B2B2B),
        ),
      );
    }

    setState(() => _isListening = true);
    await PulseAIAudioService.instance.startListening(
      onResult: (words) {
        if (!mounted) return;
        setState(() {
          _textController.text = words;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        if (error.trim().isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white),
              ),
              backgroundColor: const Color(0xFF2B2B2B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              action: SnackBarAction(
                label: 'Type',
                textColor: const Color(0xFFFF5252),
                onPressed: () => _focusNode.requestFocus(),
              ),
            ),
          );
        }
      },
    );
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
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const ConsentSheetWidget(),
    );
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    _textController.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    final currentLocale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    await ref.read(assistantProvider.notifier).sendMessage(
          query,
          currentLocale,
          screenContext: widget.screenContext,
        );
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/pulseai_icon.png',
              width: 32,
              height: 32,
              cacheWidth: 64,
              cacheHeight: 64,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.smart_toy_outlined,
                size: 28,
                color: Color(0xFFC30121),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'PulseAI',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFFC30121),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Pinned Banner
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "AI-assisted guidance — not a medical diagnosis. Always consult a doctor.",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Messages Area with isolated 3D ECG heartbeat background
          Expanded(
            child: Ecg3DBackground(
              isThinking: state.isSending,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: state.isLoading && state.messages.isEmpty
                      ? const Center(child: AppLoader())
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.messages.length +
                              (state.isSending ? 1 : 0) +
                              (state.errorCode != null ? 1 : 0) +
                              1,
                          itemBuilder: (context, index) {
                            if (index == 0 && state.errorCode != null) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: _PulseAiErrorBanner(
                                  errorCode: state.errorCode!,
                                  requestId: state.requestId,
                                  onRetry: () {
                                    final currentLocale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
                                    ref.read(assistantProvider.notifier).retryLastMessage(
                                          currentLocale,
                                          screenContext: widget.screenContext,
                                        );
                                  },
                                ),
                              );
                            }
                            if (index == (state.errorCode != null ? 1 : 0) && state.isSending) {
                              return const TypingIndicator();
                            }

                            final messageIndex = state.messages.length -
                                1 -
                                (index -
                                    (state.isSending ? 1 : 0) -
                                    (state.errorCode != null ? 1 : 0));

                            if (messageIndex < 0) {
                              return _buildEmptyState(context);
                            }

                            final message = state.messages[messageIndex];
                            return MessageWidget(message: message);
                          },
                        ),
                ),
              ),
            ),
          ),

          // Quick Actions & Input Bar - anchored safely above keyboard & navigation bar
          SafeArea(
            top: false,
            bottom: true,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFDF3F3),
              ),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick Actions above input bar
                  if (state.quickActions.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: state.quickActions
                            .map((q) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActionChip(
                                    label: Text(
                                      q.textEn,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF2B2B2B)),
                                    ),
                                    onPressed: () => _sendMessage(q.textEn),
                                    backgroundColor: const Color(0xFFF3DDE0),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 6),
                  // Input Field capsule - Decorated Input Bar (Anomaly #23)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: _isListening
                            ? AppColors.primary
                            : (_focusNode.hasFocus ? AppColors.primary : const Color(0xFFE2D6D6)),
                        width: (_focusNode.hasFocus || _isListening) ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_focusNode.hasFocus || _isListening)
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: (_focusNode.hasFocus || _isListening) ? 12 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF5A6E85), size: 20),
                          tooltip: 'Scan Blood Report',
                          onPressed: () => context.push('/health-hub/ai-report'),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLength: 500,
                            minLines: 1,
                            maxLines: 4,
                            enabled: !state.isSending,
                            decoration: const InputDecoration(
                              hintText: "Ask PulseAI or paste lab results...",
                              hintStyle: TextStyle(color: Color(0xFF888888), fontSize: 13, fontFamily: 'Inter'),
                              border: InputBorder.none,
                              counterText: "",
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: _sendMessage,
                          ),
                        ),
                        if (!kIsWeb) ...[
                          const SizedBox(width: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: _isListening ? const Color(0xFFC30121).withOpacity(0.15) : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none_outlined,
                                color: _isListening ? const Color(0xFFC30121) : Colors.grey,
                                size: 20,
                              ),
                              tooltip: _isListening ? "Listening... Tap to stop" : "Speak in Bangla or English",
                              onPressed: _toggleVoiceInput,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _textController,
                          builder: (context, value, child) {
                            final canSend = value.text.trim().isNotEmpty && !state.isSending;
                            return Container(
                              decoration: BoxDecoration(
                                color: canSend ? const Color(0xFFC30121) : Colors.grey.shade300,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                                onPressed: canSend ? () => _sendMessage(_textController.text) : null,
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
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
                      Flexible(
                        child: Text(
                          "End-to-end encrypted clinical triage session",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isBangla = (Localizations.maybeLocaleOf(context)?.languageCode == 'bn') ||
        (GetLocale.locale?.languageCode == 'bn');

    final suggestions = isBangla
        ? [
            'আমি কি রক্ত দিতে পারব?',
            'কত ঘন ঘন রক্ত দেওয়া যায়?',
            'রক্তদানের আগে কী খাওয়া উচিত?',
          ]
        : [
            'Am I eligible to donate?',
            'How often can I donate?',
            'What should I eat before donating?',
          ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage('assets/images/pulseai_icon.png'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AssistantBubble(
                  text: isBangla
                      ? "স্বাগতম! আমি **PulseAI**, আপনার রক্তদান ও ক্লিনিক্যাল সহকারী। রক্তদানের যোগ্যতা, নিয়ম বা স্বাস্থ্য বিষয়ক যেকোনো প্রশ্ন করতে পারেন।"
                      : "Hello! I'm **PulseAI**, your clinical companion for transfusion medicine, donation deferrals, lab diagnostics, and emergency donor mobilization.\n\nHow can I assist you with your donation or clinical inquiries today?",
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions.map((s) {
                return ActionChip(
                  label: Text(
                    s,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFC30121),
                    ),
                  ),
                  backgroundColor: Colors.white,
                  elevation: 1,
                  shadowColor: Colors.black12,
                  side: const BorderSide(color: Color(0xFFF3DDE0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  onPressed: () => _sendMessage(s),
                );
              }).toList(),
            ),
          ),
        ],
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
            const SizedBox(width: 8),
            AvatarHelper(
              radius: 16,
              fallbackName: ref.watch(authProvider).user?.fullName ?? 'User',
              serverPhotoUrl: ref.watch(authProvider).user?.photoUrl,
              googlePhotoUrl: ref.watch(authProvider).user?.googlePhotoUrl,
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
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            backgroundImage: AssetImage('assets/images/pulseai_icon.png'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AssistantBubble(text: message.text),
                
                if (message.action == 'complete_profile')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC30121),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                      label: const Text(
                        'Complete profile',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        final auth = ref.read(authProvider);
                        final u = auth.user;
                        final isGoogle = u?.authProvider == 'google' ||
                            (u != null && u.email.isNotEmpty && u.authProvider != 'credentials');
                        context.push(
                          '/register',
                          extra: {
                            'prefillName': u?.fullName ?? '',
                            'prefillEmail': u?.email ?? '',
                            'isGoogleUser': isGoogle,
                          },
                        );
                      },
                    ),
                  ),

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

                // Feedback and TTS Speak button
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
                      if (!kIsWeb) ...[
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () {
                            PulseAIAudioService.instance.speakText(
                              message.text,
                              lang: message.language,
                              onVoiceCheck: (hint) {
                                if (hint != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(hint),
                                      duration: const Duration(seconds: 4),
                                      backgroundColor: const Color(0xFF2B2B2B),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.volume_up_outlined, size: 14, color: Colors.grey),
                              SizedBox(width: 4),
                              Text("Listen", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
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
    final lines = text.split('\n');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildMarkdownContent(lines),
      ),
    );
  }

  List<Widget> _buildMarkdownContent(List<String> lines) {
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (i < lines.length - 1 && lines[i + 1].trim().isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
        continue;
      }

      final isBullet = line.startsWith('* ') || line.startsWith('- ') || line.startsWith('• ');
      final isNumbered = RegExp(r'^\d+\.\s+').hasMatch(line);

      if (isBullet || isNumbered) {
        final content = isBullet
            ? line.substring(2).trim()
            : line.replaceFirst(RegExp(r'^\d+\.\s+'), '').trim();
        final prefix = isNumbered ? RegExp(r'^\d+\.').firstMatch(line)!.group(0)! : '•';

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: isNumbered ? 24 : 16,
                  child: Text(
                    prefix,
                    style: TextStyle(
                      color: const Color(0xFFC30121),
                      fontWeight: FontWeight.bold,
                      fontSize: isNumbered ? 13 : 16,
                      height: 1.3,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildRichText(content),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _buildRichText(line),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildRichText(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: const TextStyle(
              color: Color(0xFF2B2B2B),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            color: Color(0xFF2B2B2B),
            fontWeight: FontWeight.bold,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: const TextStyle(
            color: Color(0xFF2B2B2B),
            fontSize: 14,
            height: 1.45,
          ),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
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
  const ConsentSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "BloodPulse Assistant Privacy",
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "The assistant uses AI to help answer your questions. Please do not share any personal health information or phone numbers.",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  height: 1.35,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(assistantProvider.notifier).saveConsent(true);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC30121),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "Accept & Continue",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white,
          backgroundImage: AssetImage('assets/images/pulseai_icon.png'),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF3F3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC30121).withValues(alpha: 0.15)),
          ),
          child: const AppLoader.small(
            color: Color(0xFFC30121),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR BANNER — single inline card with Retry button and mapped EN/BN messages
// ─────────────────────────────────────────────────────────────────────────────

class GetLocale {
  static Locale? locale;
}

class _PulseAiErrorBanner extends StatelessWidget {
  const _PulseAiErrorBanner({
    required this.errorCode,
    required this.onRetry,
    this.requestId,
  });

  final String errorCode;
  final VoidCallback onRetry;
  final String? requestId;

  static _ErrorInfo _infoFor(String code, bool isBangla) {
    switch (code) {
      case 'NO_INTERNET':
      case 'OFFLINE':
        return _ErrorInfo(
          Icons.wifi_off_rounded,
          isBangla ? 'ইন্টারনেট সংযোগ নেই' : 'You are offline',
          isBangla
              ? 'আপনার ইন্টারনেট সংযোগ পরীক্ষা করে পুনরায় চেষ্টা করুন।'
              : 'Check your connection and try again.',
        );
      case 'TIMEOUT':
      case 'BUSY':
        return _ErrorInfo(
          Icons.timer_outlined,
          isBangla ? 'সময় শেষ হয়ে গেছে' : 'Request timed out',
          isBangla
              ? 'সার্ভার সাড়া দিতে বিলম্ব হচ্ছে। অনুগ্রহ করে আবার চেষ্টা করুন।'
              : 'PulseAI is taking longer than usual. Please try again.',
        );
      case 'LOGIN_REQUIRED':
      case 'AUTH_EXPIRED':
        return _ErrorInfo(
          Icons.lock_outline_rounded,
          isBangla ? 'সেশনের মেয়াদ শেষ' : 'Session expired',
          isBangla
              ? 'আপনার সেশনের মেয়াদ শেষ হয়ে গেছে। অনুগ্রহ করে আবার সাইন ইন করুন।'
              : 'Your session may have expired. Please sign in again.',
        );
      case 'RATE_LIMITED':
        return _ErrorInfo(
          Icons.hourglass_top_rounded,
          isBangla ? 'বার্তা সীমা অতিক্রম' : 'Too many messages',
          isBangla
              ? 'আপনি অতিরিক্ত বার্তা পাঠিয়েছেন। কিছুক্ষণ অপেক্ষা করে আবার চেষ্টা করুন।'
              : 'You\'ve sent too many messages. Please wait a moment before trying again.',
        );
      case 'SERVER_ERROR':
        return _ErrorInfo(
          Icons.cloud_off_rounded,
          isBangla ? 'সার্ভারে সমস্যা হয়েছে' : 'Server error',
          isBangla
              ? 'সার্ভারে একটি সমস্যা হয়েছে। কিছুক্ষণ পর আবার চেষ্টা করুন।'
              : 'PulseAI encountered an issue on our server. Please try again in a moment.',
        );
      case 'PROVIDER_ERROR':
        return _ErrorInfo(
          Icons.smart_toy_outlined,
          isBangla ? 'এআই সেবা অনুপলব্ধ' : 'AI service unavailable',
          isBangla
              ? 'এআই সেবা সাময়িকভাবে অনুপলব্ধ। অনুগ্রহ করে কিছুক্ষণ পর চেষ্টা করুন।'
              : 'The AI provider is temporarily unavailable. Please try again.',
        );
      case 'EMPTY_RESPONSE':
        return _ErrorInfo(
          Icons.chat_bubble_outline_rounded,
          isBangla ? 'কোনো উত্তর পাওয়া যায়নি' : 'No response received',
          isBangla
              ? 'কোনো উত্তর পাওয়া যায়নি। অনুগ্রহ করে আবার জিজ্ঞাসা করুন।'
              : 'PulseAI returned an empty response. Please try asking again.',
        );
      default:
        return _ErrorInfo(
          Icons.error_outline_rounded,
          isBangla ? 'একটি সমস্যা হয়েছে' : 'PulseAI is busy',
          isBangla
              ? 'কিছুক্ষণ পর আবার চেষ্টা করুন।'
              : 'Something went wrong on our end. Please try again in a moment.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = (Localizations.maybeLocaleOf(context)?.languageCode == 'bn') ||
        (GetLocale.locale?.languageCode == 'bn');
    final info = _infoFor(errorCode, isBangla);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC30121).withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, color: const Color(0xFFC30121), size: 32),
          const SizedBox(height: 8),
          Text(
            info.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFFC30121),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            info.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.black87,
              height: 1.35,
            ),
          ),
          if (requestId != null && requestId!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Request ID: $requestId',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(isBangla ? 'আবার চেষ্টা করুন' : 'Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC30121),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorInfo {
  const _ErrorInfo(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}
