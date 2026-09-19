import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/locale_provider.dart';
import '../../../blood_request/presentation/providers/blood_request_provider.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../providers/donor_search_provider.dart';

const Map<String, List<String>> _divisionDistricts = {
  'Dhaka': ['Dhaka', 'Gazipur', 'Narayanganj', 'Tangail', 'Faridpur', 'Manikganj', 'Munshiganj', 'Narsingdi', 'Gopalganj', 'Kishoreganj', 'Madaripur', 'Rajbari', 'Shariatpur'],
  'Chattogram': ['Chattogram', 'Cox\'s Bazar', 'Cumilla', 'Feni', 'Brahmanbaria', 'Chandpur', 'Noakhali', 'Lakshmipur', 'Khagrachhari', 'Rangamati', 'Bandarban'],
  'Rajshahi': ['Rajshahi', 'Bogura', 'Pabna', 'Sirajganj', 'Naogaon', 'Natore', 'Chapai Nawabganj', 'Joypurhat'],
  'Khulna': ['Khulna', 'Jashore', 'Kushtia', 'Satkhira', 'Bagerhat', 'Chuadanga', 'Jhenaidah', 'Magura', 'Meherpur', 'Narail'],
  'Barishal': ['Barishal', 'Bhola', 'Jhalokati', 'Patuakhali', 'Pirojpur', 'Barguna'],
  'Sylhet': ['Sylhet', 'Moulvibazar', 'Habiganj', 'Sunamganj'],
  'Rangpur': ['Rangpur', 'Dinajpur', 'Kurigram', 'Gaibandha', 'Nilphamari', 'Panchagarh', 'Thakurgaon', 'Lalmonirhat'],
  'Mymensingh': ['Mymensingh', 'Jamalpur', 'Netrokona', 'Sherpur'],
};

/// The Complete Multi-Mode Blood Hub View implementing both Mobile & Desktop Parity.
/// Mode 0: Hub Landing ("The Heart of Giving" / "ব্লাড হাব")
/// Mode 1: Donor Search & Live Interactive Map
/// Mode 2: Emergency Blood Request & Multi-Channel Verification
class BloodHubView extends ConsumerStatefulWidget {
  const BloodHubView({super.key, this.initialMode = 0});

  final int initialMode;

  @override
  ConsumerState<BloodHubView> createState() => _BloodHubViewState();
}

class _BloodHubViewState extends ConsumerState<BloodHubView> {
  late int _activeMode; // 0 = Landing, 1 = Search, 2 = Request

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialMode;
  }

  void _triggerIdentityVerification({
    required VoidCallback onVerified,
    required String patientName,
    required String bloodGroup,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (ctx) => _IdentityVerificationModal(
        onSuccess: onVerified,
        patientName: patientName,
        bloodGroup: bloodGroup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isBangla = locale.languageCode == 'bn';

    return _buildMobileLayout(isBangla);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE BLOOD HUB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(bool isBangla) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-Nav Toggle (Visible when inside Search or Request)
          if (_activeMode != 0) ...[
            _buildSubNavToggle(),
            const SizedBox(height: 16),
          ],

          if (_activeMode == 0)
            _buildMobileLanding(isBangla)
          else if (_activeMode == 1)
            _buildDonorSearchSection()
          else
            _buildEmergencyRequestSection(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMobileLanding(bool isBangla) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFFC30121), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      isBangla ? 'ব্লাড কমিউনিটি' : 'Vital Community',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isBangla ? 'ব্লাড হাব' : 'The Heart of Giving',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isBangla
                    ? 'ব্লাড হাবে আপনাকে স্বাগতম। আপনি জীবন রক্ষাকারী রক্ত খুঁজছেন বা জরুরি সহায়তার অনুরোধ করছেন, আমরা আপনাকে নিঃস্বার্থ বীরদের একটি নেটওয়ার্কের সাথে যুক্ত করি।'
                    : 'Welcome to the Blood Hub. Whether you’re searching for a life-saving match or requesting urgent support, we connect you to a network of selfless heroes.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Card 1: Search for Donor ──
        _buildActionOptionCard(
          icon: Icons.person_search_rounded,
          iconBgColor: const Color(0xFFFEE9EB),
          iconColor: const Color(0xFFC30121),
          title: isBangla ? 'দাতা খুঁজুন' : 'Search for Donor',
          subtitle: isBangla
              ? 'রক্তের গ্রুপ, অবস্থান এবং উপস্থাতর উপর ভিত্তি করে আমাদের স্থানীয় যাচাইকৃত দাতাদের ডাটাবেস ব্রাউজ করুন।'
              : 'Access our verified database of local donors filtered by blood type, proximity, and availability.',
          badgeWidget: Row(
            children: [
              _buildBloodGroupPill('A+'),
              const SizedBox(width: 6),
              _buildBloodGroupPill('O+'),
              const SizedBox(width: 6),
              _buildBloodGroupPill('B+'),
            ],
          ),
          buttonText: isBangla ? 'এখনই খুঁজুন ➔' : 'Find Now ➔',
          onTap: () => setState(() => _activeMode = 1),
        ),

        const SizedBox(height: 16),

        // ── Card 2: Request for Blood ──
        _buildActionOptionCard(
          icon: Icons.water_drop_rounded,
          iconBgColor: const Color(0xFFC30121),
          iconColor: Colors.white,
          title: isBangla ? 'রক্তের জন্য অনুরোধ করুন' : 'Request for Blood',
          subtitle: isBangla
              ? 'জরুরি রক্ত সঞ্চালনের প্রয়োজনের জন্য আপনার এলাকার সকল যোগ্য দাতাকে তাৎক্ষণিকভাবে অবহিত করুন।'
              : 'Instantly notify all eligible donors in your area for urgent transfusion needs or planned procedures.',
          badgeWidget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE9EB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'URGENT REQUESTS NEARBY: 12',
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
            ),
          ),
          buttonText: isBangla ? 'অনুরোধ পোস্ট করুন ➔' : 'Post Request ➔',
          onTap: () => setState(() => _activeMode = 2),
        ),

        const SizedBox(height: 16),

        // ── Card 3: Blood Donation Campaigns ──
        _buildActionOptionCard(
          icon: Icons.campaign_rounded,
          iconBgColor: const Color(0xFFE8F1F8),
          iconColor: const Color(0xFF0D68AA),
          title: isBangla ? 'রক্তদান ক্যাম্পেইন' : 'Blood Donation Campaigns',
          subtitle: isBangla
              ? 'আসন্ন রক্তদান ক্যাম্পেইন, ড্রাইভ এবং সমাজকল্যাণমূলক ইভেন্টগুলো দেখুন ও অংশগ্রহণ করুন।'
              : 'Discover upcoming donation drives, university camps, and community blood collection events.',
          badgeWidget: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1F8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ACTIVE DRIVES',
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D68AA)),
            ),
          ),
          buttonText: isBangla ? 'ক্যাম্পেইন দেখুন ➔' : 'View Campaigns ➔',
          onTap: () {
            ref.read(feedFilterProvider.notifier).state = 'campaign';
            ref.read(shellTabProvider.notifier).state = 0; // Switches directly to Feed tab
          },
        ),

        const SizedBox(height: 24),

        // Feature Highlights
        _buildFeatureTile(
          icon: Icons.verified_user_outlined,
          title: isBangla ? 'যাচাইকৃত নেটওয়ার্ক' : 'Verified Network',
          subtitle: isBangla
              ? 'সকল দাতা আপনার সুরক্ষা এবং মানসিক শান্তির জন্য কঠোর স্বাস্থ্য যাচাইয়ের মধ্য দিয়ে যান।'
              : 'All donors undergo strict health verification for your safety and peace of mind.',
        ),
        _buildFeatureTile(
          icon: Icons.near_me_outlined,
          title: isBangla ? 'স্মার্ট অবস্থান' : 'Smart Proximity',
          subtitle: isBangla
              ? 'আমাদের অ্যালগরিদম আপনার অনুরোধের কয়েক মিনিটের মধ্যে সবচেয়ে কাছের উপযুক্ত ম্যাচ সনাক্ত করে।'
              : 'Our algorithm identifies the closest compatible matches within minutes of your request.',
        ),
        _buildFeatureTile(
          icon: Icons.history_rounded,
          title: isBangla ? 'অনুরোধের ইতিহাস' : 'Request History',
          subtitle: isBangla
              ? 'আপনার সক্রিয় অনুরোধগুলি ট্র্যাক করুন এবং আপনার ড্যাশবোর্ডে পূর্ববর্তী সফল ম্যাচগুলি পর্যালোচনা করুন।'
              : 'Track your active requests and review past successful matches in your dashboard.',
        ),
      ],
    );
  }
  // ─────────────────────────────────────────────────────────────────────────
  // SUB-NAV TOGGLE (Search Donors vs Request Blood)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSubNavToggle() {
    return Center(
      child: Container(
        height: 48,
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: const Color(0xFFE2E2E2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeMode = 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: _activeMode == 1 ? const Color(0xFFC30121) : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Search as Donor',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _activeMode == 1 ? Colors.white : const Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeMode = 2),
                child: Container(
                  decoration: BoxDecoration(
                    color: _activeMode == 2 ? const Color(0xFFC30121) : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Request for Blood',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _activeMode == 2 ? Colors.white : const Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DONOR SEARCH & LIVE MAP SECTION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDonorSearchSection() {
    final donors = ref.watch(filteredDonorsProvider);
    final filter = ref.watch(donorSearchFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchFilterCard(filter),
        const SizedBox(height: 20),
        Text(
          'Available Donors (${donors.length} found near you)',
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
        ),
        const SizedBox(height: 12),
        for (final donor in donors) ...[
          _buildDonorCard(donor),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 20),
        _buildLiveMapContainer(donors),
      ],
    );
  }

  Widget _buildSearchFilterCard(DonorSearchFilter filter) {
    final availableDistricts = filter.division != null ? (_divisionDistricts[filter.division] ?? []) : <String>[];
    const availableCampuses = [
      'All Campuses',
      'Dhaka Medical College',
      'BUET Campus',
      'Dhaka University',
      'Chittagong Medical College',
      'RUET Campus, Rajshahi',
      'Sylhet MAG Osmani Medical',
      'Mymensingh Medical College',
      'Khulna Medical College',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Find a Donor',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Select criteria to locate matches in real-time.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF888888)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  ref.read(donorSearchFilterProvider.notifier).state = const DonorSearchFilter();
                },
                child: const Text('Clear all', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC30121))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Input
          TextField(
            onChanged: (val) {
              ref.read(donorSearchFilterProvider.notifier).state = filter.copyWith(searchQuery: val);
            },
            decoration: InputDecoration(
              hintText: 'Search by Name, Campus, or Location...',
              hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF888888)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFC30121)),
              filled: true,
              fillColor: const Color(0xFFFDF3F3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(50),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Row 1: Blood Group & Division
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF3F3),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFF9D2D7)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: filter.bloodGroup ?? 'Any',
                      items: ['Any', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((bg) {
                        return DropdownMenuItem(value: bg, child: Text('Blood: $bg', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC30121))));
                      }).toList(),
                      onChanged: (val) {
                        ref.read(donorSearchFilterProvider.notifier).state = filter.copyWith(bloodGroup: val == 'Any' ? null : val, clearBloodGroup: val == 'Any');
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF3F3),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFF9D2D7)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: filter.division ?? 'All Divisions',
                      items: ['All Divisions', ..._divisionDistricts.keys].map((div) {
                        return DropdownMenuItem(value: div, child: Text(div, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF2B2B2B))));
                      }).toList(),
                      onChanged: (val) {
                        ref.read(donorSearchFilterProvider.notifier).state = filter.copyWith(
                          division: val == 'All Divisions' ? null : val,
                          clearDivision: val == 'All Divisions',
                          clearZila: true,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Cascading Zila (District) & Campus
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF3F3),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFF9D2D7)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: filter.zila ?? 'All Zilas',
                      items: ['All Zilas', ...availableDistricts].map((zila) {
                        return DropdownMenuItem(value: zila, child: Text(zila, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF2B2B2B))));
                      }).toList(),
                      onChanged: (val) {
                        ref.read(donorSearchFilterProvider.notifier).state = filter.copyWith(
                          zila: val == 'All Zilas' ? null : val,
                          clearZila: val == 'All Zilas',
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF3F3),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFF9D2D7)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: filter.campus ?? 'All Campuses',
                      items: availableCampuses.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF2B2B2B)), overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) {
                        ref.read(donorSearchFilterProvider.notifier).state = filter.copyWith(
                          campus: val == 'All Campuses' ? null : val,
                          clearCampus: val == 'All Campuses',
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonorCard(DonorSearchResult donor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFFEE9EB),
            child: Text(
              donor.name.isNotEmpty ? donor.name.substring(0, 1) : 'D',
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      donor.name,
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                    ),
                    if (donor.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF0D68AA)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '📍 ${donor.campusOrLocation}',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF666666)),
                ),
                Text(
                  '🩸 ${donor.lastDonationText}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: donor.isAvailable ? const Color(0xFF1B8A4E) : const Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  donor.bloodGroup,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
                ),
              ),
              const SizedBox(height: 8),
              if (donor.isAvailable)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC30121),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    elevation: 0,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Direct blood request sent to ${donor.name}!'),
                        backgroundColor: const Color(0xFF1B8A4E),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Request', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                )
              else
                const Text('Unavailable', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF888888))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMapContainer(List<DonorSearchResult> donors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nearby Donor Network',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
              ),
              TextButton.icon(
                onPressed: () => context.push('/map'),
                icon: const Icon(Icons.fullscreen_rounded, size: 16, color: Color(0xFFC30121)),
                label: const Text('Full Screen Map', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC30121))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 320,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: const LatLng(23.7259, 90.3976),
                  initialZoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'org.bloodpulse.app',
                  ),
                  MarkerLayer(
                    markers: donors.map((d) {
                      return Marker(
                        point: d.location,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: d.isAvailable ? const Color(0xFFC30121) : const Color(0xFF888888),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            d.bloodGroup,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Icon(Icons.circle, size: 8, color: Color(0xFFC30121)),
              SizedBox(width: 4),
              Text('Available Donors', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF666666))),
              SizedBox(width: 16),
              Icon(Icons.circle, size: 8, color: Color(0xFF888888)),
              SizedBox(width: 4),
              Text('Unavailable', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF666666))),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMERGENCY BLOOD REQUEST SECTION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEmergencyRequestSection() {
    return _EmergencyRequestFormContent(
      onTriggerVerification: (patientName, bloodGroup, onSuccess) {
        _triggerIdentityVerification(
          onVerified: onSuccess,
          patientName: patientName,
          bloodGroup: bloodGroup,
        );
      },
      onSuccessSubmitted: () {
        setState(() => _activeMode = 0);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER WIDGETS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActionOptionCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget badgeWidget,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF9D2D7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF666666), height: 1.4),
          ),
          const SizedBox(height: 14),
          badgeWidget,
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC30121),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              onPressed: onTap,
              child: Text(
                buttonText,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupPill(String bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE9EB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(bg, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC30121))),
    );
  }

  Widget _buildFeatureTile({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFFEE9EB), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFFC30121), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF666666), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMERGENCY REQUEST FORM CONTENT
// ─────────────────────────────────────────────────────────────────────────────
class _EmergencyRequestFormContent extends ConsumerStatefulWidget {
  const _EmergencyRequestFormContent({
    required this.onTriggerVerification,
    required this.onSuccessSubmitted,
  });

  final Function(String patientName, String bloodGroup, VoidCallback onSuccess) onTriggerVerification;
  final VoidCallback onSuccessSubmitted;

  @override
  ConsumerState<_EmergencyRequestFormContent> createState() => _EmergencyRequestFormContentState();
}

class _EmergencyRequestFormContentState extends ConsumerState<_EmergencyRequestFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _patientNameCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _hospitalLocationCtrl = TextEditingController();
  final _dateTimeCtrl = TextEditingController(text: 'Today, Immediate');

  String? _selectedBloodType = 'O-';
  String _urgencyLevel = 'Urgent (Immediate)';
  Uint8List? _medicalReportBytes;
  Uint8List? _patientPhotoBytes;

  @override
  void dispose() {
    _patientNameCtrl.dispose();
    _conditionCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _hospitalLocationCtrl.dispose();
    _dateTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedicalReport(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _medicalReportBytes = bytes);
      }
    } catch (_) {}
  }

  Future<void> _pickPatientPhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _patientPhotoBytes = bytes);
      }
    } catch (_) {}
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final patientName = _patientNameCtrl.text.trim();
    final bloodGroup = _selectedBloodType ?? 'O+';
    final hospital = _hospitalLocationCtrl.text.trim();
    final contact = _contactPhoneCtrl.text.trim();

    // FRAUD RULE: If user attached a verified medical report, post directly!
    // If NOT attached, trigger Multi-Channel Identity Verification (Email OTP)!
    if (_medicalReportBytes != null) {
      await _executeDirectPost(patientName, bloodGroup, hospital, contact);
    } else {
      widget.onTriggerVerification(patientName, bloodGroup, () async {
        await _executeDirectPost(patientName, bloodGroup, hospital, contact);
      });
    }
  }

  Future<void> _executeDirectPost(String patientName, String bloodGroup, String hospital, String contact) async {
    final success = await ref.read(bloodRequestProvider.notifier).createRequest(
          patientName: patientName,
          bloodGroup: bloodGroup,
          urgencyLevel: _urgencyLevel,
          hospitalLocation: hospital,
          contactNumber: contact,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 Emergency request broadcast to nearby donors & added to Profile!'),
            backgroundColor: Color(0xFF1B8A4E),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSuccessSubmitted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Emergency Blood Request',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Fill in the details below to broadcast an urgent request to nearby donors.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 28),

            // Patient Photo (Optional)
            GestureDetector(
              onTap: _pickPatientPhoto,
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE9EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF9D2D7)),
                    ),
                    child: _patientPhotoBytes != null
                        ? ClipOval(child: Image.memory(_patientPhotoBytes!, width: 80, height: 80, fit: BoxFit.cover))
                        : const Icon(Icons.camera_alt_outlined, color: Color(0xFFC30121), size: 30),
                  ),
                  const SizedBox(height: 6),
                  const Text('Upload Patient Photo (Optional)', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF888888))),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Patient Details Fields
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Patient Name'),
                  const SizedBox(height: 6),
                  CustomInputField(
                    controller: _patientNameCtrl,
                    hint: 'Enter full name',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Patient name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Required Blood Type'),
                  const SizedBox(height: 6),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: const Color(0xFFE2E2E2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedBloodType,
                        items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((bg) {
                          return DropdownMenuItem(value: bg, child: Text(bg, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC30121))));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedBloodType = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Disease / Condition'),
                  const SizedBox(height: 6),
                  CustomInputField(
                    controller: _conditionCtrl,
                    hint: 'e.g. Surgery, Accident, Anemia, Thalassemia',
                    prefixIcon: Icons.medical_services_outlined,
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Contact Phone Number'),
                  const SizedBox(height: 6),
                  CustomInputField(
                    controller: _contactPhoneCtrl,
                    hint: '+880 1XX XXX XXXX',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 11) ? 'Valid contact number is required' : null,
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Hospital Location & Address'),
                  const SizedBox(height: 6),
                  CustomInputField(
                    controller: _hospitalLocationCtrl,
                    hint: 'Search hospital name or address (e.g. Dhaka Medical College)',
                    prefixIcon: Icons.local_hospital_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Hospital address is required' : null,
                  ),
                  const SizedBox(height: 16),

                  _fieldLabel('Urgency Level'),
                  const SizedBox(height: 6),
                  Row(
                    children: ['Normal (Within 24h)', 'Urgent (Immediate)', 'Custom'].map((u) {
                      final isSelected = _urgencyLevel == u;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _urgencyLevel = u),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFC30121) : const Color(0xFFFDF3F3),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              u,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF666666),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Medical Verification Box
                  _fieldLabel('Medical Verification (Optional / Instant Fast-Track)'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF9D2D7)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_upload_outlined, color: Color(0xFFC30121), size: 36),
                        const SizedBox(height: 8),
                        Text(
                          _medicalReportBytes != null
                              ? '✅ Medical Report Attached (Instant Fast-Track Active)'
                              : 'Tap to upload medical report or blood test result (PNG, JPG up to 10MB)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _medicalReportBytes != null ? const Color(0xFF1B8A4E) : const Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                side: const BorderSide(color: Color(0xFFC30121)),
                              ),
                              icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFFC30121)),
                              label: const Text('Camera', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFC30121))),
                              onPressed: () => _pickMedicalReport(ImageSource.camera),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC30121),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.file_upload_outlined, size: 16, color: Colors.white),
                              label: const Text('Files', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white)),
                              onPressed: () => _pickMedicalReport(ImageSource.gallery),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: CapsuleButton(
                label: 'Submit Request ➔',
                showGlow: true,
                onPressed: _submitRequest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF444444)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MULTI-CHANNEL IDENTITY VERIFICATION MODAL (EMAIL OTP & WHATSAPP)
// ─────────────────────────────────────────────────────────────────────────────
class _IdentityVerificationModal extends ConsumerStatefulWidget {
  const _IdentityVerificationModal({
    required this.onSuccess,
    required this.patientName,
    required this.bloodGroup,
  });

  final VoidCallback onSuccess;
  final String patientName;
  final String bloodGroup;

  @override
  ConsumerState<_IdentityVerificationModal> createState() => _IdentityVerificationModalState();
}

class _IdentityVerificationModalState extends ConsumerState<_IdentityVerificationModal> {
  final _emailCtrl = TextEditingController(text: 'donor@gmail.com');
  final List<TextEditingController> _pinControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());

  bool _otpSent = false;
  int _countdown = 45;
  Timer? _timer;
  bool _isEmailChannel = true;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null && user.email.isNotEmpty) {
      _emailCtrl.text = user.email;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 45);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address.'),
          backgroundColor: Color(0xFFC30121),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _otpSent = true);
    _startCountdown();

    final success = await ref
        .read(authProvider.notifier)
        .sendVerificationEmail(email: email);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔑 6-digit verification code sent to $email!'),
          backgroundColor: const Color(0xFF0D68AA),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final err = ref.read(authProvider).errorMessage ?? 'Failed to send verification email.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: const Color(0xFFC30121),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _verifyAndSubmit() async {
    final enteredCode = _pinControllers.map((c) => c.text).join().trim();
    if (enteredCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 6-digit verification code.'),
          backgroundColor: Color(0xFFC30121),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .verifyEmailCode(code: enteredCode, email: _emailCtrl.text.trim());

    if (!mounted) return;

    if (success) {
      ref.read(authProvider.notifier).setEmailVerified(true);
      Navigator.pop(context);
      widget.onSuccess();
    } else {
      final err = ref.read(authProvider).errorMessage ?? 'Invalid or expired code. Please request a new code.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: const Color(0xFFC30121),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(28, 20, 28, MediaQuery.viewInsetsOf(context).bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          const Text(
            'Identity Verification',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
          ),
          if (_otpSent) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Verification code sent to ${_emailCtrl.text}',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D68AA)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Channel Select (Email OTP vs WhatsApp)
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFDF3F3),
              borderRadius: BorderRadius.circular(50),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isEmailChannel = true),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isEmailChannel ? const Color(0xFFC30121) : Colors.transparent,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mail_outline_rounded, size: 16, color: _isEmailChannel ? Colors.white : const Color(0xFF666666)),
                          const SizedBox(width: 6),
                          Text('Email OTP', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: _isEmailChannel ? Colors.white : const Color(0xFF666666))),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isEmailChannel = false),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_isEmailChannel ? const Color(0xFFC30121) : Colors.transparent,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 16, color: !_isEmailChannel ? Colors.white : const Color(0xFF666666)),
                          const SizedBox(width: 6),
                          Text('WhatsApp', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: !_isEmailChannel ? Colors.white : const Color(0xFF666666))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Email Input & Send OTP Button
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  controller: _emailCtrl,
                  hint: 'Enter your email address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC30121),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  elevation: 0,
                ),
                onPressed: _sendOtp,
                child: const Text('Send OTP', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 6-Digit PIN Boxes
          const Text('Enter 6-Digit OTP', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              return Container(
                width: 44,
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _pinControllers[i],
                  focusNode: _pinFocusNodes[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFFDF3F3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF9D2D7)),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && i < 5) {
                      _pinFocusNodes[i + 1].requestFocus();
                    } else if (val.isEmpty && i > 0) {
                      _pinFocusNodes[i - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),

          const SizedBox(height: 14),

          // Resend Timer
          Text(
            _countdown > 0 ? 'Resend code in 00:${_countdown.toString().padLeft(2, '0')}' : 'Didn’t receive code? Tap Send OTP again.',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF888888)),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: CapsuleButton(
              label: 'Verify & Submit Request ➔',
              showGlow: true,
              onPressed: _verifyAndSubmit,
            ),
          ),
        ],
      ),
    );
  }
}
