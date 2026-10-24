// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/core/widgets/avatar_helper.dart';

import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../../core/access/access_guard.dart';
import '../../../../core/access/registration_gate_popup.dart';
import '../../../../core/services/image_compression_service.dart';
import '../../../../services/api_client.dart';
import 'guest_lock_card.dart';
import '../providers/feed_provider.dart';
import '../providers/user_location_provider.dart';

/// Comprehensive Feed View supporting both Mobile and Desktop layout parity.

String _resolveMediaUrl(String rawUrl) {
  if (rawUrl.isEmpty) return '';
  if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
    if (rawUrl.contains('storage.bloodpulse.local')) {
      final base = ApiClient().baseUrl.endsWith('/')
          ? ApiClient().baseUrl.substring(0, ApiClient().baseUrl.length - 1)
          : ApiClient().baseUrl;
      return rawUrl.replaceFirst('https://storage.bloodpulse.local', base);
    }
    return rawUrl;
  }
  final base = ApiClient().baseUrl.endsWith('/')
      ? ApiClient().baseUrl.substring(0, ApiClient().baseUrl.length - 1)
      : ApiClient().baseUrl;
  final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
  return '$base$path';
}

class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView> {
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userLocationProvider.notifier).refreshCoarseLocation();
    });
  }

  Future<void> _handleRefresh() async {
    await ref.read(userLocationProvider.notifier).refreshCoarseLocation(force: true);
    final latestLoc = ref.read(userLocationProvider);
    await ref.read(feedProvider.notifier).fetchPosts(
      scope: 'near',
      district: latestLoc.districtName,
      division: latestLoc.divisionName,
      reset: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserLocationState>(userLocationProvider, (previous, next) {
      if (previous?.districtName != next.districtName && next.districtName != null) {
        ref.read(feedProvider.notifier).fetchPosts(
          scope: 'near',
          district: next.districtName,
          division: next.divisionName,
          reset: true,
        );
      }
    });

    return _buildMobileLayout();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE FEED LAYOUT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    final allPosts = ref.watch(feedProvider);
    final filter = ref.watch(feedFilterProvider);

    final posts = filter == null
        ? allPosts
        : (filter == 'emergency'
            ? allPosts.where((p) => p.urgentNeedBadge != null).toList()
            : allPosts.where((p) => p.postType == filter || (filter == 'campaign' && p.campaign != null)).toList());

    return RefreshIndicator(
      color: const Color(0xFFC30121),
      backgroundColor: Colors.white,
      onRefresh: _handleRefresh,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: posts.length + (posts.isEmpty ? 2 : 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filter == null) ...[
                  _PostCreatorCard(picker: _picker),
                  const SizedBox(height: 12),
                ],
                _buildSegmentFilterBar(filter),
                if (filter != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: filter == 'campaign' ? const Color(0xFFEDF4FF) : const Color(0xFFFEE9EB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: filter == 'campaign' ? const Color(0xFF0D68AA).withAlpha(50) : const Color(0xFFC30121).withAlpha(50),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          filter == 'campaign' ? Icons.campaign_rounded : Icons.emergency_rounded,
                          color: filter == 'campaign' ? const Color(0xFF0D68AA) : const Color(0xFFC30121),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filter == 'campaign' ? 'Blood Donation Campaigns & Drives' : 'Emergency Blood SOS Requests',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: filter == 'campaign' ? const Color(0xFF0D68AA) : const Color(0xFFC30121),
                                ),
                              ),
                              Text(
                                filter == 'campaign'
                                    ? 'Pledge your donation to community drives near you'
                                    : 'Urgent requests verified by attending hospitals',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.read(feedFilterProvider.notifier).state = null,
                          style: TextButton.styleFrom(
                            backgroundColor: filter == 'campaign' ? const Color(0xFF0D68AA) : const Color(0xFFC30121),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Show All',
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          }

          if (posts.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    filter == 'campaign' ? Icons.campaign_outlined : Icons.bloodtype_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    filter == 'campaign' ? 'No active campaigns found' : 'No emergency requests at this moment',
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Check back soon or view all community posts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final post = posts[index - 1];
          final isLast = index == posts.length;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 40.0 : 12.0),
            child: _FeedPostCard(post: post),
          );
        },
      ),
    );
  }

  Widget _buildSegmentFilterBar(String? currentFilter) {
    // USER RULE - do not change: D2 soft red pill sliding between chips with AnimatedAlign (250ms)
    const segments = [
      {'id': null, 'label': 'All Updates'},
      {'id': 'campaign', 'label': 'Campaign'},
      {'id': 'emergency', 'label': 'Emergency'},
    ];

    final selectedIndex = currentFilter == null
        ? 0
        : (currentFilter == 'campaign' ? 1 : 2);
    final alignmentX = selectedIndex == 0 ? -1.0 : (selectedIndex == 1 ? 0.0 : 1.0);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F7),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFF3E5E5)),
      ),
      padding: const EdgeInsets.all(3),
      child: Stack(
        children: [
          // Sliding soft red pill (AnimatedAlign, 250ms)
          AnimatedAlign(
            alignment: Alignment(alignmentX, 0.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1.0 / segments.length,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E9),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: const Color(0xFFF0B8BC), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC30121).withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Interactive tab labels (No tick icon, selected red, unselected gray)
          Row(
            children: segments.map((seg) {
              final isSelected = currentFilter == seg['id'];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(feedFilterProvider.notifier).state = seg['id'];
                    ref.read(feedProvider.notifier).fetchPosts(kind: seg['id'], reset: true);
                  },
                  child: Center(
                    child: Text(
                      seg['label'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFFC30121) : const Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// POST CREATOR CARD (Top Card)
// ─────────────────────────────────────────────────────────────────────────────

class _PostCreatorCard extends ConsumerStatefulWidget {
  const _PostCreatorCard({required this.picker});
  final ImagePicker picker;

  @override
  ConsumerState<_PostCreatorCard> createState() => _PostCreatorCardState();
}

class _PostCreatorCardState extends ConsumerState<_PostCreatorCard> {
  final _textCtrl = TextEditingController();
  final List<Uint8List> _attachedImages = [];
  final List<Map<String, dynamic>> _uploadedMedia = [];
  String? _clinicCheckIn;
  String _selectedKind = 'general';
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _uploadFailed = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final authState = ref.read(authProvider);
    final isGuest = ref.read(isGuestProvider);
    final isIncomplete = authState.user != null && !authState.user!.isProfileComplete;
    if (isGuest || isIncomplete) {
      RegistrationGatePopup.show(context, isGuest: isGuest);
      return;
    }
    if (_attachedImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 4 photos per post allowed.'),
          backgroundColor: Color(0xFFC30121),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final pickedList = await widget.picker.pickMultiImage(imageQuality: 85);
      if (pickedList.isNotEmpty) {
        final availableSlots = 4 - _attachedImages.length;
        final toAdd = pickedList.take(availableSlots).toList();

        for (final picked in toAdd) {
          final rawBytes = await picked.readAsBytes();
          // Compress via ImageCompressionService (< 300KB, max 1280px, strip EXIF)
          final compressedBytes = await ImageCompressionService.compressImageBytes(rawBytes);
          setState(() {
            _attachedImages.add(compressedBytes);
            _uploadFailed = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach image: $e')),
        );
      }
    }
  }

  Future<bool> _uploadAttachedImages() async {
    if (_attachedImages.isEmpty) return true;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
      _uploadFailed = false;
    });

    final apiClient = ApiClient();
    _uploadedMedia.clear();

    for (int i = 0; i < _attachedImages.length; i++) {
      try {
        final bytes = _attachedImages[i];
        final filename = 'feed_image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final res = await apiClient.uploadMultipart(
          'media/upload/',
          fileBytes: bytes,
          filename: filename,
        );
        _uploadedMedia.add(res);
        if (mounted) {
          setState(() {
            _uploadProgress = (i + 1) / _attachedImages.length;
          });
        }
      } catch (e) {
        debugPrint('[PostCreatorCard] Upload failed for image $i: $e');
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadFailed = true;
          });
        }
        return false;
      }
    }

    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
      });
    }
    return true;
  }

  Future<void> _onPost() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _attachedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write your donation story or attach a photo before posting.'),
          backgroundColor: Color(0xFFC30121),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authState = ref.read(authProvider);
    final isGuest = ref.read(isGuestProvider);
    final isIncomplete = authState.user != null && !authState.user!.isProfileComplete;
    if (isGuest || isIncomplete) {
      RegistrationGatePopup.show(context, isGuest: isGuest);
      return;
    }

    // Upload images first
    if (_attachedImages.isNotEmpty) {
      final uploadOk = await _uploadAttachedImages();
      if (!uploadOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo upload failed. Please tap retry or cancel.'),
              backgroundColor: Color(0xFFC30121),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final user = ref.read(authProvider).user;
    final author = user?.fullName.isNotEmpty == true ? user!.fullName : 'Donor Altruist';

    ref.read(feedProvider.notifier).addPost(
      authorName: author,
      content: text,
      media: _uploadedMedia,
      imageBytes: _attachedImages.isNotEmpty ? _attachedImages.first : null,
      location: _clinicCheckIn,
      kind: _selectedKind,
      onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post failed: $err'),
              backgroundColor: const Color(0xFFC30121),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    _textCtrl.clear();
    setState(() {
      _attachedImages.clear();
      _uploadedMedia.clear();
      _clinicCheckIn = null;
      _uploadProgress = 0.0;
      _uploadFailed = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story posted to BloodPulse community! 🎉'),
          backgroundColor: Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openCheckInModal() {
    final authState = ref.read(authProvider);
    final isGuest = ref.read(isGuestProvider);
    final isIncomplete = authState.user != null && !authState.user!.isProfileComplete;
    if (isGuest || isIncomplete) {
      RegistrationGatePopup.show(context, isGuest: isGuest);
      return;
    }
    final locationCtrl = TextEditingController(text: _clinicCheckIn ?? '');
    final popularLocations = [
      'General Hospital',
      'City Clinic',
      'Evercare Hospital, Dhaka',
      'Bangabandhu Sheikh Mujib Med. University (BSMMU)',
      'Bangladesh Red Crescent Blood Center',
      'Shaheed Suhrawardy Medical College',
      'National Heart Foundation Hospital',
      'Uttara Crescent Hospital',
      'Chattogram Medical College Hospital',
      'Sylhet MAG Osmani Medical College',
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFFC30121), size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Check In Location',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF666666)),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: const Color(0xFFC30121).withValues(alpha: 0.35), width: 1.2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: TextField(
                      controller: locationCtrl,
                      autofocus: true,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF2B2B2B)),
                      decoration: const InputDecoration(
                        hintText: 'Enter hospital, clinic, or donation center...',
                        hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF8E7D7F)),
                        border: InputBorder.none,
                        isDense: true,
                        icon: Icon(Icons.search, size: 18, color: Color(0xFFC30121)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Popular Blood Donation Centers',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF0D68AA)),
                        label: const Text('Current Location (GPS)', style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF0D68AA), fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFFEDF4FF),
                        side: const BorderSide(color: Color(0xFFD0E4FF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        onPressed: () async {
                          await ref.read(userLocationProvider.notifier).refreshCoarseLocation(force: true);
                          final loc = ref.read(userLocationProvider);
                          final locName = loc.districtName ?? 'Dhaka';
                          setModalState(() {
                            locationCtrl.text = '$locName (GPS)';
                          });
                        },
                      ),
                      for (final loc in popularLocations)
                        ActionChip(
                          avatar: const Icon(Icons.local_hospital_outlined, size: 14, color: Color(0xFFC30121)),
                          label: Text(loc, style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF2B2B2B))),
                          backgroundColor: locationCtrl.text == loc ? const Color(0xFFFFF0F1) : const Color(0xFFF8F9FA),
                          side: BorderSide(
                            color: locationCtrl.text == loc ? const Color(0xFFC30121) : const Color(0xFFE5E7EB),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          onPressed: () {
                            setModalState(() {
                              locationCtrl.text = loc;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (_clinicCheckIn != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _clinicCheckIn = null);
                            Navigator.pop(sheetCtx);
                          },
                          child: const Text('Clear Check In', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
                        ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC30121),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final entered = locationCtrl.text.trim();
                          setState(() {
                            _clinicCheckIn = entered.isNotEmpty ? entered : null;
                          });
                          Navigator.pop(sheetCtx);
                        },
                        child: const Text(
                          'Add Location',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AvatarHelper(
                radius: 18,
                fallbackName: user?.fullName ?? 'User',
                serverPhotoUrl: user?.photoUrl,
                googlePhotoUrl: user?.googlePhotoUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6F6),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFC30121), width: 1.8),
                  ),
                  child: TextField(
                    controller: _textCtrl,
                    onTap: () {
                      final authState = ref.read(authProvider);
                      final isGuest = ref.read(isGuestProvider);
                      final isIncomplete = authState.user != null && !authState.user!.isProfileComplete;
                      if (isGuest || isIncomplete) {
                        FocusScope.of(context).unfocus();
                        RegistrationGatePopup.show(context, isGuest: isGuest);
                      }
                    },
                    cursorColor: const Color(0xFFC30121),
                    cursorWidth: 2.0,
                    cursorRadius: const Radius.circular(2),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF2B2B2B)),
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?...",
                      hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF9E9E9E)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 9),
                    ),
                    maxLines: null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _onPost,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFFC30121),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Upload progress / failed retry banner
          if (_isUploading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: const Color(0xFFF9D2D7),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC30121)),
                minHeight: 4,
              ),
            ),
          ],

          if (_uploadFailed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC30121).withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFC30121), size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Upload failed. Tap retry or cancel.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFFC30121)),
                    ),
                  ),
                  TextButton(
                    onPressed: _onPost,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC30121))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Color(0xFF888888)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _attachedImages.clear();
                        _uploadFailed = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],

          // Attached Images Grid (up to 4)
          if (_attachedImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _attachedImages.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _attachedImages[i],
                          height: 75,
                          width: 75,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _attachedImages.removeAt(i);
                              _uploadFailed = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],


          if (_clinicCheckIn != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFE6BDBA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFFC30121)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _clinicCheckIn!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC30121),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _clinicCheckIn = null),
                        child: const Icon(Icons.close, size: 14, color: Color(0xFFC30121)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 16),

          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined, size: 16, color: Color(0xFFC30121)),
                      label: const Text(
                        'Photo',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _openCheckInModal,
                      icon: Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: _clinicCheckIn != null ? const Color(0xFFC30121) : const Color(0xFF666666),
                      ),
                      label: Text(
                        _clinicCheckIn != null ? 'Check In: $_clinicCheckIn' : 'Check In',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _clinicCheckIn != null ? const Color(0xFFC30121) : const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC30121),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  elevation: 0,
                ),
                onPressed: _onPost,
                child: const Text(
                  'Post',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEED POST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _FeedPostCard extends ConsumerStatefulWidget {
  const _FeedPostCard({required this.post});
  final FeedPostItem post;

  @override
  ConsumerState<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<_FeedPostCard> {
  bool _showComments = false;
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _onSendComment() async {
    final authState = ref.read(authProvider);
    final isGuest = ref.read(isGuestProvider);
    final isIncomplete = authState.user != null && !authState.user!.isProfileComplete;
    if (isGuest || isIncomplete) {
      RegistrationGatePopup.show(context, isGuest: isGuest);
      return;
    }
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    _commentFocus.unfocus();
    await ref.read(feedProvider.notifier).addComment(
      widget.post.id,
      text,
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: const Color(0xFFC30121),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Future<void> _sharePost(FeedPostItem post) async {
    ref.read(feedProvider.notifier).incrementShare(post.id);
    final locationText = post.location != null ? '📍 Location: ${post.location}\n\n' : '';
    final shareText = '🩸 BloodPulse Community Alert:\n'
        '${post.authorName} posted: "${post.content}"\n\n'
        '$locationText'
        'Join BloodPulse to save lives together: https://bloodpulse.app';

    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      final result = await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'BloodPulse Story from ${post.authorName}',
          sharePositionOrigin: origin,
        ),
      );
      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Shared successfully! Thank you for spreading the word.'),
              ],
            ),
            backgroundColor: Color(0xFF1B8A4E),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Story copied to clipboard! Ready to paste & share.'),
                ),
              ],
            ),
            backgroundColor: Color(0xFF0D68AA),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isUrgent = post.urgentNeedBadge != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (isUrgent)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 5,
                child: Container(color: const Color(0xFFC30121)),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Repost attribution banner ──
                  if (post.repostedBy != null) ...[
                    Container(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.repeat_rounded, size: 16, color: Color(0xFF1B8A4E)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${post.repostedBy} reposted',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B8A4E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Header: Avatar, Name, Badges, 3-dot ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AvatarHelper(
                        radius: 20,
                        fallbackName: post.authorName,
                        serverPhotoUrl: post.authorAvatar,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.authorName,
                                    style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2B2B2B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (post.roleBadgeText != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: post.authorRole == AuthorRole.verifiedClinic
                                          ? const Color(0xFFE8F1FF)
                                          : const Color(0xFFFFF2D6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      post.roleBadgeText!,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: post.authorRole == AuthorRole.verifiedClinic
                                            ? const Color(0xFF0D68AA)
                                            : const Color(0xFFB57900),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post.location != null ? '${post.timestamp} • 📍 ${post.location}' : post.timestamp,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF888888)),
                        onSelected: (val) {
                          if (val == 'share') {
                            _sharePost(post);
                          } else if (val == 'save') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Post saved to your bookmarks!'),
                                backgroundColor: Color(0xFF0D68AA),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else if (val == 'report') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thank you. Our moderation team will review this post.'),
                                backgroundColor: Color(0xFFC30121),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'save', child: Text('Save Post')),
                          const PopupMenuItem(value: 'share', child: Text('Share Story')),
                          const PopupMenuItem(value: 'report', child: Text('Report')),
                        ],
                      ),
                    ],
                  ),

          // ── Urgent / Blood Group Badges ──
          if (post.urgentNeedBadge != null || post.bloodGroupBadge != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (post.urgentNeedBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE9EB),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFC30121)),
                        const SizedBox(width: 4),
                        Text(
                          post.urgentNeedBadge!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC30121),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (post.bloodGroupBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC30121),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      post.bloodGroupBadge!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // ── Content Text ──
          Text(
            post.content,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF2B2B2B),
              height: 1.5,
            ),
          ),

          // ── Attached Media Images (If any) ──
          if (post.media.isNotEmpty || post.imageUrl != null || post.imageBytes != null) ...[
            const SizedBox(height: 14),
            if (post.imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  post.imageBytes!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ] else if (post.media.isNotEmpty) ...[
              if (post.media.length == 1) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: _resolveMediaUrl(post.media.first['url']?.toString().replaceFirst('/upload/', '/upload/w_600,q_auto,f_auto/') ?? ''),
                    memCacheWidth: 600,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 220,
                      color: const Color(0xFFF7ECEC),
                      child: const Center(
                        child: AppLoader.small(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 220,
                      color: const Color(0xFFF7ECEC),
                      child: const Icon(Icons.broken_image_rounded, color: Color(0xFFC30121)),
                    ),
                  ),
                ),
              ] else ...[
                // Multi-image grid (2 to 4)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: post.media.length,
                  itemBuilder: (context, mIdx) {
                    final itemUrl = _resolveMediaUrl(post.media[mIdx]['url']?.toString().replaceFirst('/upload/', '/upload/w_400,q_auto,f_auto/') ?? '');
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: itemUrl,
                        memCacheWidth: 400,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF7ECEC),
                          child: const Center(
                            child: AppLoader.small(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFF7ECEC),
                          child: const Icon(Icons.broken_image_rounded, color: Color(0xFFC30121)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ] else if (post.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: post.imageUrl!.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: post.imageUrl!.replaceFirst('/upload/', '/upload/w_600,q_auto,f_auto/'),
                        memCacheWidth: 600,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 220,
                          color: const Color(0xFFF7ECEC),
                          child: const Center(
                            child: AppLoader.small(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 220,
                          color: const Color(0xFFF7ECEC),
                          child: const Icon(Icons.broken_image_rounded, color: Color(0xFFC30121)),
                        ),
                      )
                    : Image.asset(
                        post.imageUrl!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
              ),
            ],
          ],

          // Failed retry banner for optimistic post
          if (post.isFailed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC30121).withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFC30121), size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Failed to post. Tap to retry or dismiss.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFFC30121)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(feedProvider.notifier).removeFailedPost(post.id);
                      ref.read(feedProvider.notifier).addPost(
                        authorName: post.authorName,
                        content: post.content,
                        media: post.media,
                        imageBytes: post.imageBytes,
                        imageUrl: post.imageUrl,
                        bloodGroupBadge: post.bloodGroupBadge,
                        urgentNeedBadge: post.urgentNeedBadge,
                        location: post.location,
                        kind: post.kind,
                      );
                    },
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC30121))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Color(0xFF888888)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      ref.read(feedProvider.notifier).removeFailedPost(post.id);
                    },
                  ),
                ],
              ),
            ),
          ],


          // ── Achievement Badge Box (e.g. Sarah Mitchell 5th donation) ──
          if (post.achievementBadge != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF9D2D7)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE9EB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFC30121), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.achievementBadge!,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC30121),
                          ),
                        ),
                        const Text(
                          'Keep donating to unlock the Diamond Lifesaver badge!',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Campaign Drive Info & Progress Card ──
          if (post.campaign != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0D68AA).withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: Color(0xFF0D68AA), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.campaign!.title,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D68AA),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF666666)),
                      const SizedBox(width: 4),
                      Text(
                        post.campaign!.startDate,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF666666)),
                      ),
                      const Spacer(),
                      Text(
                        '${post.campaign!.currentUnits} / ${post.campaign!.targetUnits} bags',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D68AA)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (post.campaign!.currentUnits / post.campaign!.targetUnits).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D68AA)),
                    ),
                  ),
                  const SizedBox(height: 10),
                    SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(feedProvider.notifier).pledgeCampaign(post.id);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Thank you! You pledged 1 unit to ${post.campaign!.title}. Current progress: ${post.campaign!.currentUnits + 1}/${post.campaign!.targetUnits} bags.',
                              style: const TextStyle(fontFamily: 'Inter'),
                            ),
                            backgroundColor: const Color(0xFF1B8A4E),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.volunteer_activism_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        'Pledge Blood Donation',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D68AA),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 18),

          // ── Interaction Actions Row: Like, Comment, Repost, Share ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like Action (Love)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final authState = ref.read(authProvider);
                    final isGuest = ref.read(isGuestProvider);
                    final isIncomplete = authState.user != null && !authState.user!.isProfileComplete;
                    if (isGuest || isIncomplete) {
                      RegistrationGatePopup.show(context, isGuest: isGuest);
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    ref.read(feedProvider.notifier).toggleReact(
                      post.id,
                      onError: (error) {
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: const Color(0xFFC30121),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        AnimatedScale(
                          scale: post.isReacted ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            post.isReacted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 19,
                            color: post.isReacted ? const Color(0xFFC30121) : const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.reactCount}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: post.isReacted ? const Color(0xFFC30121) : const Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Comment Action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final authState = ref.read(authProvider);
                    final isGuest = ref.read(isGuestProvider);
                    final isIncomplete = authState.user != null && !authState.user!.isProfileComplete;
                    if (isGuest || isIncomplete) {
                      RegistrationGatePopup.show(context, isGuest: isGuest);
                      return;
                    }
                    setState(() => _showComments = !_showComments);
                    if (_showComments) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) _commentFocus.requestFocus();
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _showComments ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: _showComments ? const Color(0xFFC30121) : const Color(0xFF666666),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.commentCount}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _showComments ? const Color(0xFFC30121) : const Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Repost Action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    if (ref.read(isGuestProvider)) {
                      RegistrationGatePopup.show(context, isGuest: true);
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    final authUser = ref.read(authProvider).user;
                    final reposterName = authUser?.fullName.isNotEmpty == true ? authUser!.fullName : 'You';
                    final success = await ref.read(feedProvider.notifier).repost(
                      post.id,
                      reposterName: reposterName,
                      onError: (error) {
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: const Color(0xFFC30121),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                    if (success) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                Icons.repeat_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text('Reposted to your timeline & community feed!'),
                            ],
                          ),
                          backgroundColor: Color(0xFF1B8A4E),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 19,
                          color: post.isReposted ? const Color(0xFF1B8A4E) : const Color(0xFF666666),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          post.repostCount > 0 ? 'Repost (${post.repostCount})' : 'Repost',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: post.isReposted ? const Color(0xFF1B8A4E) : const Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Share Action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _sharePost(post),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.share_outlined, size: 18, color: Color(0xFF666666)),
                        if (post.shareCount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${post.shareCount}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Comments Expansion ──
          if (_showComments) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Comments List
            if (post.comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No comments yet. Write a warm note to ${post.authorName}!',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF888888), fontStyle: FontStyle.italic),
                ),
              ),

            for (final c in post.comments) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AvatarHelper(
                      radius: 12,
                      fallbackName: c.authorName,
                      serverPhotoUrl: c.authorAvatar,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF3F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.authorName,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.text,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF444444)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Add Comment Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _commentFocus,
                    onSubmitted: (_) => _onSendComment(),
                    decoration: InputDecoration(
                      hintText: 'Write a warm reply...',
                      hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF888888)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFFDF3F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFFC30121), size: 20),
                  onPressed: _onSendComment,
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  ],
),
),
);
}
}

class _ProfileCompletionBanner extends ConsumerWidget {
  const _ProfileCompletionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null || user.isProfileComplete) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C8D0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC30121).withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFC30121), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Complete Registration',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC30121),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC30121),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Declare your blood group, phone number, and district to request blood, view verified donor contacts, and join local communities.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF555555),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC30121),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Complete Profile',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
