import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/otp_provider.dart';

/// The Complete 3-Sub-Page Blood Hub View implementing the Stitch Design System.
/// Sub-Page 1: Hub Overview ("The Heart of Giving" Landing Page)
/// Sub-Page 2: Donor Search ("Search as Donor" Filters & Verified Donor Cards)
/// Sub-Page 3: Emergency Blood Requisition Form ("Request for Blood")
class BloodHubView extends ConsumerStatefulWidget {
  const BloodHubView({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<BloodHubView> createState() => _BloodHubViewState();
}

class _BloodHubViewState extends ConsumerState<BloodHubView> {
  late int _activeSubTabIndex;

  @override
  void initState() {
    super.initState();
    _activeSubTabIndex = widget.initialTabIndex;
  }

  void _triggerJitVerification(VoidCallback onSuccess) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _JitVerificationSheet(),
    ).then((_) {
      if (ref.read(authProvider).user?.isOtpVerified == true) {
        onSuccess();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      backgroundColor: AppColors.surface,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Top Segmented Toggle Navigation Bar (Matching Stitch Mockup) ────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0xFFE6BDBA)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildSegmentTab(0, 'Hub Overview', Icons.home_work_outlined),
                _buildSegmentTab(1, 'Search Donors', Icons.person_search_outlined),
                _buildSegmentTab(2, 'Request Blood', Icons.water_drop_outlined),
              ],
            ),
          ),

          // ── Sub-Page Body View Switcher ──────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _activeSubTabIndex,
              children: [
                _HubOverviewSubView(
                  onNavigateSearch: () => setState(() => _activeSubTabIndex = 1),
                  onNavigateRequest: () {
                    final auth = ref.read(authProvider);
                    if (auth.user?.isOtpVerified == true) {
                      setState(() => _activeSubTabIndex = 2);
                    } else {
                      _triggerJitVerification(() {
                        setState(() => _activeSubTabIndex = 2);
                      });
                    }
                  },
                ),
                _DonorSearchSubView(
                  onRequestDonor: (donorName) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📩 Direct blood request sent to $donorName!'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _EmergencyRequestFormSubView(
                  onSubmitted: () {
                    setState(() => _activeSubTabIndex = 0);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(int index, String label, IconData icon) {
    final bool isSelected = _activeSubTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSubTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.secondary,
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

// ─────────────────────────────────────────────────────────────────────────────
// SUB-PAGE 1: HUB OVERVIEW ("The Heart of Giving" Landing Page)
// ─────────────────────────────────────────────────────────────────────────────

class _HubOverviewSubView extends ConsumerWidget {
  const _HubOverviewSubView({
    required this.onNavigateSearch,
    required this.onNavigateRequest,
  });

  final VoidCallback onNavigateSearch;
  final VoidCallback onNavigateRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ── Vital Community Badge & Hero Headline ──────────────────────────
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F1),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0xFFE6BDBA)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_rounded, color: AppColors.primary, size: 14),
                SizedBox(width: 6),
                Text(
                  'Vital Community',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'The Heart of Giving',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),

        Text(
          'Welcome to the Blood Hub. Whether you\'re searching for a life-saving match or requesting urgent support, we connect you to a network of selfless heroes.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.neutral,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // ── Card 1: Search for Donor ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6BDBA)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_search_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Search for Donor',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Access our verified database of local donors filtered by blood type, proximity, and availability.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Filter preview chips
              Row(
                children: [
                  _buildBloodGroupChip('A+'),
                  const SizedBox(width: 6),
                  _buildBloodGroupChip('O+'),
                  const SizedBox(width: 6),
                  _buildBloodGroupChip('B+'),
                  const Spacer(),
                  CapsuleButton(
                    label: 'Find Now →',
                    height: 40,
                    onPressed: onNavigateSearch,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Card 2: Request for Blood ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6BDBA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Request for Blood',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Instantly notify all eligible donors in your area for urgent transfusion needs or planned procedures.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral, height: 1.4),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: const Color(0xFFE6BDBA)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.brightness_1_rounded, color: AppColors.primary, size: 8),
                    SizedBox(width: 6),
                    Text(
                      'URGENT REQUESTS NEARBY: 12',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              CapsuleButton(
                label: 'Post Request +',
                icon: Icons.add_alert_rounded,
                showGlow: true,
                onPressed: onNavigateRequest,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Feature Highlights List ──────────────────────────────────────────
        _buildFeatureTile(
          icon: Icons.verified_user_outlined,
          title: 'Verified Network',
          subtitle: 'All donors undergo strict health verification for your safety and peace of mind.',
        ),
        _buildFeatureTile(
          icon: Icons.near_me_outlined,
          title: 'Smart Proximity',
          subtitle: 'Our algorithm identifies the closest compatible matches within minutes of your request.',
        ),
        _buildFeatureTile(
          icon: Icons.history_rounded,
          title: 'Request History',
          subtitle: 'Track your active requests and review past successful matches in your dashboard.',
        ),
        const SizedBox(height: 24),

        // ── Interactive Live Map Box ────────────────────────────────────────
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: const DecorationImage(
              image: NetworkImage('https://tile.openstreetmap.org/13/4825/3342.png'),
              fit: BoxFit.cover,
            ),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [Colors.black.withAlpha(120), Colors.black.withAlpha(40)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Center(
                child: CapsuleButton(
                  label: '548 Active Donors Online',
                  icon: Icons.map_outlined,
                  height: 44,
                  onPressed: () => context.go('/donor-map'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBloodGroupChip(String bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFE6BDBA)),
      ),
      child: Text(
        bg,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildFeatureTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-PAGE 2: DONOR SEARCH ("Search as Donor" Screen 2 from Stitch Mockup)
// ─────────────────────────────────────────────────────────────────────────────

class _DonorSearchSubView extends StatefulWidget {
  const _DonorSearchSubView({required this.onRequestDonor});

  final Function(String donorName) onRequestDonor;

  @override
  State<_DonorSearchSubView> createState() => _DonorSearchSubViewState();
}

class _DonorSearchSubViewState extends State<_DonorSearchSubView> {
  final _searchCtrl = TextEditingController();
  String? _selectedBloodGroup = 'All';
  String? _selectedDivision = 'All';

  final List<Map<String, String>> _sampleDonors = [
    {
      'name': 'Zahir Raihan',
      'verified': 'true',
      'bloodGroup': 'A+',
      'location': 'Dhaka Medical College',
      'lastDonation': '3 months ago',
    },
    {
      'name': 'Anika Tabassum',
      'verified': 'true',
      'bloodGroup': 'O-',
      'location': 'Mirpur, Dhaka',
      'lastDonation': '6 months ago',
    },
    {
      'name': 'Samiul Islam',
      'verified': 'true',
      'bloodGroup': 'B+',
      'location': 'Dhanmondi, Dhaka',
      'lastDonation': '1 year ago',
    },
    {
      'name': 'Farhana Yeasmin',
      'verified': 'true',
      'bloodGroup': 'AB+',
      'location': 'Uttara, Dhaka',
      'lastDonation': '2 months ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Search Input
        CustomInputField(
          controller: _searchCtrl,
          label: 'Search Donor',
          hint: 'Search by Name, Location...',
          prefixIcon: Icons.search_rounded,
        ),
        const SizedBox(height: 12),

        // Filter Dropdowns Row
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                label: 'Blood Group',
                value: _selectedBloodGroup,
                items: ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                onChanged: (val) => setState(() => _selectedBloodGroup = val),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFilterDropdown(
                label: 'Division',
                value: _selectedDivision,
                items: ['All', 'Dhaka', 'Chattogram', 'Rajshahi', 'Khulna', 'Sylhet'],
                onChanged: (val) => setState(() => _selectedDivision = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Results Header Count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Donors',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFEDF4FF), borderRadius: BorderRadius.circular(50)),
              child: const Text(
                '128 found near you',
                style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.tertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Donor List Cards
        ..._sampleDonors.map((d) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            d['name']!,
                            style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: AppColors.tertiary, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${d['location']}',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '📅 Last Donation: ${d['lastDonation']}',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F1),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: const Color(0xFFE6BDBA)),
                      ),
                      child: Text(
                        d['bloodGroup']!,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CapsuleButton(
                      label: 'Request',
                      height: 36,
                      onPressed: () => widget.onRequestDonor(d['name']!),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12)),
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-PAGE 3: EMERGENCY BLOOD REQUISITION FORM (Screen 3 from Stitch Mockup)
// ─────────────────────────────────────────────────────────────────────────────

class _EmergencyRequestFormSubView extends ConsumerStatefulWidget {
  const _EmergencyRequestFormSubView({required this.onSubmitted});

  final VoidCallback onSubmitted;

  @override
  ConsumerState<_EmergencyRequestFormSubView> createState() => _EmergencyRequestFormSubViewState();
}

class _EmergencyRequestFormSubViewState extends ConsumerState<_EmergencyRequestFormSubView> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameCtrl = TextEditingController();
  final _hospitalLocationCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();

  String? _selectedBloodGroup = 'O+';
  String _urgencyLevel = 'Urgent (Immediate)';
  File? _patientPhoto;
  File? _medicalReport;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(bool isPhoto) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isPhoto) {
          _patientPhoto = File(image.path);
        } else {
          _medicalReport = File(image.path);
        }
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Emergency Blood Request Broadcasted to Nearby Donors!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSubmitted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Blood Request',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Fill in the details below to broadcast an urgent request to matching donors.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
            ),
            const SizedBox(height: 20),

            // ── Section 1: Patient Photo ─────────────────────────────────────
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _pickImage(true),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE6BDBA), width: 2),
                      ),
                      child: _patientPhoto != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(_patientPhoto!, fit: BoxFit.cover))
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 36),
                                SizedBox(height: 6),
                                Text('Upload Photo', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Section 2: Patient Details ───────────────────────────────────
            CustomInputField(
              controller: _patientNameCtrl,
              label: 'Patient Full Name',
              hint: 'Enter patient full name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBloodGroup,
                        isExpanded: true,
                        hint: const Text('Blood Type'),
                        items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((bg) {
                          return DropdownMenuItem(value: bg, child: Text('Required Blood: $bg'));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedBloodGroup = val),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            CustomInputField(
              controller: _conditionCtrl,
              label: 'Disease / Condition',
              hint: 'e.g. Surgery, Accident, Anemia',
              prefixIcon: Icons.medical_services_outlined,
            ),
            const SizedBox(height: 12),

            CustomInputField(
              controller: _contactPhoneCtrl,
              label: 'Contact Phone Number',
              hint: 'Enter contact phone',
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: 20),

            // ── Section 3: Location & Urgency ────────────────────────────────
            const Text('Location & Urgency Level', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
            const SizedBox(height: 12),

            CustomInputField(
              controller: _hospitalLocationCtrl,
              label: 'Hospital Name & Location',
              hint: 'e.g. Dhaka Medical College Hospital',
              prefixIcon: Icons.local_hospital_outlined,
            ),
            const SizedBox(height: 14),

            const Text('Urgency Level:', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildUrgencyChip('Normal (Within 24h)'),
                const SizedBox(width: 6),
                _buildUrgencyChip('Urgent (Immediate)'),
              ],
            ),
            const SizedBox(height: 20),

            // ── Section 4: Medical Report Verification ──────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_outlined, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Upload Prescription / Medical Report', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CapsuleButton(
                    label: _medicalReport != null ? 'Report Attached ✓' : 'Attach Medical Document',
                    icon: Icons.attach_file_rounded,
                    height: 40,
                    onPressed: () => _pickImage(false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit Button ────────────────────────────────────────────────
            CapsuleButton(
              label: 'Submit Request →',
              icon: Icons.send_rounded,
              showGlow: true,
              onPressed: _submitForm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyChip(String label) {
    final bool isSelected = _urgencyLevel == label;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.secondary)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFFFF0F1),
      onSelected: (selected) {
        if (selected) setState(() => _urgencyLevel = label);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 4: JIT IDENTITY VERIFICATION SHEET (Matching Screen 4 from Stitch Mockup)
// ─────────────────────────────────────────────────────────────────────────────

class _JitVerificationSheet extends ConsumerStatefulWidget {
  const _JitVerificationSheet();

  @override
  ConsumerState<_JitVerificationSheet> createState() => _JitVerificationSheetState();
}

class _JitVerificationSheetState extends ConsumerState<_JitVerificationSheet> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _otpSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _phoneCtrl.text = user.primaryPhone;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onSendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter phone number');
      return;
    }
    setState(() => _error = null);
    await ref.read(otpStateProvider.notifier).sendOtp(primaryPhone: phone);
    setState(() => _otpSent = true);
  }

  void _onVerify() {
    final code = _codeCtrl.text.trim();
    final otpState = ref.read(otpStateProvider);

    if (code == otpState.correctCode || code == '1234') {
      ref.read(authProvider.notifier).setOtpVerified(true);
      Navigator.pop(context);
    } else {
      setState(() => _error = 'Invalid verification code. Enter 1234.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
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
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Identity Verification',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 4),
          Text(
            'To ensure patient safety, please verify your identity via OTP.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral),
          ),
          const SizedBox(height: 20),

          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.error.withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold)),
            ),

          if (!_otpSent) ...[
            CustomInputField(
              controller: _phoneCtrl,
              label: 'Mobile Number',
              hint: '+1 (555) 000-1234',
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: 16),
            CapsuleButton(
              label: 'Send OTP',
              icon: Icons.sms_outlined,
              onPressed: _onSendOtp,
            ),
          ] else ...[
            CustomInputField(
              controller: _codeCtrl,
              label: 'Enter 6-Digit OTP',
              hint: 'e.g. 1234',
              prefixIcon: Icons.lock_clock_outlined,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Resend code in 00:45', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey.shade600)),
                TextButton(
                  onPressed: _onSendOtp,
                  child: const Text('Resend Code', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CapsuleButton(
              label: 'Verify & Submit Request →',
              icon: Icons.check_circle_outline,
              showGlow: true,
              onPressed: _onVerify,
            ),
          ],
        ],
      ),
    );
  }
}
