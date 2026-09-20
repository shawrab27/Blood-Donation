import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/capsule_button.dart';
import '../../core/widgets/custom_input_field.dart';
import '../../providers/profile_countdown_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../features/feed/presentation/providers/feed_provider.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';

/// Interactive Profile Screen with Edit Profile Modal, Date Picker for Last Donation Date,
/// 120-Day Countdown Widget, Admin-Locked Blood Group Banner, and Activity Feed.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _bioController = TextEditingController(text: 'Blood donor committed to saving lives in emergency situations. 🩸');
  bool _isEditingBio = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        ref.read(authProvider.notifier).updateAvatar(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Profile picture updated!', style: TextStyle(fontFamily: 'Inter')),
              backgroundColor: Color(0xFF1B8A4E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load image: $e', style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Update Profile Picture', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Take Photo', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.tertiary),
              title: const Text('Choose from Gallery', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackInitial(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  void _showAddPostModal() {
    final textCtrl = TextEditingController();
    XFile? pickedImage;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
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
                      const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Share a Story or Update',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.neutral),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: TextField(
                      controller: textCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Share your donation experience, motivation, or need...',
                        hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (pickedImage != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.image_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pickedImage!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.secondary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 16, color: Colors.grey),
                          onPressed: () => setModalState(() => pickedImage = null),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final img = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                            maxWidth: 1080,
                            maxHeight: 720,
                          );
                          if (img != null) {
                            setModalState(() => pickedImage = img);
                          }
                        },
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 16, color: AppColors.primary),
                        label: const Text('Add Photo', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.secondary)),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final text = textCtrl.text.trim();
                                if (text.isEmpty && pickedImage == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter text or select a photo.'),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => isSubmitting = true);
                                try {
                                  final user = ref.read(authProvider).user;
                                  final authorName = user?.fullName.isNotEmpty == true
                                      ? user!.fullName
                                      : 'Blood Donor';
                                  final imageBytes = pickedImage != null ? await pickedImage!.readAsBytes() : null;

                                  final success = await ref.read(feedProvider.notifier).addPost(
                                        authorName: authorName,
                                        content: text,
                                        imageBytes: imageBytes,
                                      );

                                  if (!mounted) return;
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('🎉 Post published to community feed!'),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to publish post: $e'),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Publish Post',
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

  void _showEditProfileModal() {
    final state = ref.read(profileCountdownProvider);
    final user = state.user;

    final nameCtrl = TextEditingController(text: user?.name);
    final emailCtrl = TextEditingController(text: user?.email);
    final phoneCtrl = TextEditingController(text: user?.phonePrimary);
    final secondaryPhoneCtrl = TextEditingController(text: user?.phoneSecondary ?? '');
    final villageCtrl = TextEditingController(text: 'West Dhanmondi');
    final divisionCtrl = TextEditingController(text: user?.division);
    final districtCtrl = TextEditingController(text: user?.district);
    final upazilaCtrl = TextEditingController(text: user?.upazila);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 24,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Profile Details', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),

              CustomInputField(controller: nameCtrl, label: 'Full Name', hint: 'Enter full name', prefixIcon: Icons.person_outline),
              const SizedBox(height: 12),
              CustomInputField(controller: emailCtrl, label: 'Email Address', hint: 'Enter email', prefixIcon: Icons.email_outlined),
              const SizedBox(height: 12),
              CustomInputField(controller: phoneCtrl, label: 'Primary Phone', hint: 'Enter phone', prefixIcon: Icons.phone_outlined),
              const SizedBox(height: 12),
              CustomInputField(controller: secondaryPhoneCtrl, label: 'Secondary Phone (Optional)', hint: 'Enter secondary phone', prefixIcon: Icons.phone_android_outlined),
              const SizedBox(height: 12),
              CustomInputField(controller: villageCtrl, label: 'Village / Area', hint: 'Enter area', prefixIcon: Icons.location_on_outlined),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: CustomInputField(controller: divisionCtrl, label: 'Division', hint: 'Division')),
                  const SizedBox(width: 8),
                  Expanded(child: CustomInputField(controller: districtCtrl, label: 'District', hint: 'District')),
                  const SizedBox(width: 8),
                  Expanded(child: CustomInputField(controller: upazilaCtrl, label: 'Upazila', hint: 'Upazila')),
                ],
              ),
              const SizedBox(height: 16),

              // Attempt to Change Blood Group (Admin Approval Alert)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () {
                  _showAdminApprovalDialog();
                },
                icon: const Icon(Icons.lock_clock_outlined, color: AppColors.primary, size: 18),
                label: const Text('Request Blood Group Modification', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
              ),
              const SizedBox(height: 20),

              CapsuleButton(
                label: 'Save Profile Changes',
                icon: Icons.check_circle_outline,
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Profile details updated successfully!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminApprovalDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Admin Approval Required', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Blood group modification requires Admin authorization to prevent medical errors.\n\nWould you like to submit a blood group change request to BloodPulse Admins?',
          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.secondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder()),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📩 Modification request sent to BloodPulse Admin for review!'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Submit Request', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLastDonationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 46)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      ref.read(profileCountdownProvider.notifier).recordDonation(picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📅 Last donation date recorded: ${picked.day}/${picked.month}/${picked.year}. 120-Day countdown updated!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getBadgeEmoji(String tier) {
    switch (tier.toLowerCase()) {
      case 'golden':
        return '🥇';
      case 'silver':
        return '🥈';
      case 'bronze':
      default:
        return '🥉';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileCountdownProvider);
    final user = state.user;
    final authUser = ref.watch(authProvider).user;
    final allPosts = ref.watch(feedProvider);
    final l10n = AppLocalizations.of(context);

    final currentUserName = (authUser?.fullName.isNotEmpty == true)
        ? authUser!.fullName
        : (user?.name.isNotEmpty == true && user!.name != 'Dr. S. M. Shawrab' ? user.name : 'Blood Donor');

    final userTimelinePosts = allPosts.where((p) {
      final isAuthor = p.authorName == currentUserName ||
          (authUser != null && p.authorName == authUser.fullName) ||
          (user != null && p.authorName == user.name);
      final isReposter = p.repostedBy != null &&
          (p.repostedBy == currentUserName ||
              (authUser != null && p.repostedBy == authUser.fullName) ||
              (user != null && p.repostedBy == user.name) ||
              p.repostedBy == 'You');
      return isAuthor || isReposter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(20),
        children: [
                // ── Section 1: Header, Avatar & Badge Tier ───────────────────────
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF3DDE0),
                          border: Border.all(color: AppColors.primary, width: 3),
                        ),
                        child: ClipOval(
                          child: (authUser?.avatarBytes != null)
                              ? Image.memory(
                                  authUser!.avatarBytes!,
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover,
                                )
                              : (authUser?.photoUrl != null && authUser!.photoUrl!.isNotEmpty)
                                  ? Image.network(
                                      authUser.photoUrl!,
                                      width: 104,
                                      height: 104,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => _buildFallbackInitial(currentUserName),
                                    )
                                  : _buildFallbackInitial(currentUserName),
                        ),
                      ),

                      // Camera Overlay
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImagePickerModal,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),

                      // Tier Badge Display
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Text(_getBadgeEmoji(user?.badgeTier ?? 'Golden'), style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Name, Edit Profile Button & Role Badge
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              currentUserName,
                              style: const TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                            onPressed: _showEditProfileModal,
                            tooltip: 'Edit Profile Details',
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF4FF),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: const Color(0xFFD0E4FF)),
                        ),
                        child: Text(
                          '${authUser?.category == "student" ? "Student" : (user?.role ?? "Altruist")} • ${authUser?.categoryDetails["district"] ?? user?.institution ?? "BloodPulse Community"}',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tertiary),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Editable Bio Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _isEditingBio
                            ? TextField(
                                controller: _bioController,
                                maxLines: 2,
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                                decoration: const InputDecoration(border: InputBorder.none),
                              )
                            : Text(
                                _bioController.text,
                                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.3),
                              ),
                      ),
                      IconButton(
                        icon: Icon(_isEditingBio ? Icons.check_circle_rounded : Icons.edit_outlined, color: AppColors.primary, size: 20),
                        onPressed: () {
                          setState(() => _isEditingBio = !_isEditingBio);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Section 2: Admin-Locked Blood Group Container ─────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE6BDBA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n?.regBloodGroup ?? 'Registered Blood Group:',
                            style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(50)),
                            child: Text(
                              user?.bloodGroup ?? 'O+',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '🔒 Note: Blood Group can ONLY be edited by an Admin once saved.',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Section 4: 120-Day Donation Countdown & Date Update Widget ────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: CircularProgressIndicator(
                                  value: state.daysRemaining == 0 ? 1.0 : (120 - state.daysRemaining) / 120.0,
                                  strokeWidth: 7,
                                  backgroundColor: const Color(0xFFF3DDE0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              ),
                              Text(
                                '${state.daysRemaining}d',
                                style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.daysRemaining == 0 ? 'Ready to Donate 🎉' : '${state.daysRemaining} Days Until Eligible',
                                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state.daysRemaining == 0
                                      ? 'Your 120-day recovery countdown is complete. Respond to emergency requests now!'
                                      : 'Resting interval required to restore hemoglobin and iron levels.',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Record Last Donation Date Picker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n?.profileLastDonated ?? 'Last Donation Date:', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                          TextButton.icon(
                            onPressed: _selectLastDonationDate,
                            icon: const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.primary),
                            label: Text(
                              user?.lastDonationDate != null
                                  ? '${user!.lastDonationDate!.day}/${user.lastDonationDate!.month}/${user.lastDonationDate!.year}'
                                  : 'Update Date',
                              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Section 5: Tabbed Activity & History Sections ─────────────────
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.neutral,
                  indicatorColor: AppColors.primary,
                  labelStyle: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    const Tab(text: 'Requests Chart'),
                    const Tab(text: 'User Posts Log'),
                    Tab(text: l10n?.profileDonationHistory ?? 'Donation History'),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 260,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Requests Chart
                      ListView(
                        physics: const BouncingScrollPhysics(),
                        children: const [
                          _ActivityTile(
                            icon: Icons.emergency_rounded,
                            color: AppColors.primary,
                            title: 'Emergency Request (O+)',
                            subtitle: 'DMC Hospital • 2 Bags needed',
                            status: 'Fulfilled',
                          ),
                          _ActivityTile(
                            icon: Icons.water_drop_outlined,
                            color: AppColors.warning,
                            title: 'Urgent Request (B+)',
                            subtitle: 'Square Hospital • 1 Bag needed',
                            status: 'Active',
                          ),
                        ],
                      ),

                      // Tab 2: User Posts Log
                      ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          CapsuleButton(
                            label: 'Add Post',
                            icon: Icons.add_rounded,
                            height: 40,
                            onPressed: _showAddPostModal,
                          ),
                          const SizedBox(height: 12),
                          if (userTimelinePosts.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.feed_outlined, size: 36, color: Color(0xFFC30121)),
                                  SizedBox(height: 8),
                                  Text(
                                    'No posts or reposts yet',
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Share your donation journey or repost urgent calls from the feed to showcase them here!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral),
                                  ),
                                ],
                              ),
                            )
                          else
                            for (final p in userTimelinePosts)
                              _ActivityTile(
                                icon: p.repostedBy != null ? Icons.repeat_rounded : Icons.article_outlined,
                                color: p.repostedBy != null ? const Color(0xFF1B8A4E) : AppColors.tertiary,
                                title: p.repostedBy != null ? '🔁 Reposted • ${p.timestamp}' : 'Story • ${p.timestamp}',
                                subtitle: p.content,
                                status: '${p.reactCount} Likes',
                              ),
                        ],
                      ),

                      // Tab 3: Donation History Log
                      ListView(
                        physics: const BouncingScrollPhysics(),
                        children: const [
                          _ActivityTile(
                            icon: Icons.verified_rounded,
                            color: AppColors.success,
                            title: 'Dhaka Medical College Hospital',
                            subtitle: '10 June 2026 • 1 Bag (O+)',
                            status: 'Verified Badge',
                          ),
                          _ActivityTile(
                            icon: Icons.verified_rounded,
                            color: AppColors.success,
                            title: 'Bangabandhu Sheikh Mujib Med. University',
                            subtitle: '10 Feb 2026 • 1 Bag (O+)',
                            status: 'Verified Badge',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEDF4FF), borderRadius: BorderRadius.circular(50)),
            child: Text(status, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
          ),
        ],
      ),
    );
  }
}
