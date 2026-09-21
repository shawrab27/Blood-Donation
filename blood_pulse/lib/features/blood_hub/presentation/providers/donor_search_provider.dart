import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class DonorSearchResult {
  const DonorSearchResult({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.campusOrLocation,
    required this.division,
    required this.zila,
    required this.lastDonationText,
    required this.isVerified,
    required this.isAvailable,
    required this.location,
    this.phone = '+8801700000000',
  });

  final String id;
  final String name;
  final String bloodGroup;
  final String campusOrLocation;
  final String division;
  final String zila;
  final String lastDonationText;
  final bool isVerified;
  final bool isAvailable;
  final LatLng location;
  final String phone;
}

class DonorSearchFilter {
  const DonorSearchFilter({
    this.searchQuery = '',
    this.bloodGroup,
    this.division,
    this.zila,
    this.campus,
    this.onlyAvailable = true,
  });

  final String searchQuery;
  final String? bloodGroup;
  final String? division;
  final String? zila;
  final String? campus;
  final bool onlyAvailable;

  DonorSearchFilter copyWith({
    String? searchQuery,
    String? bloodGroup,
    String? division,
    String? zila,
    String? campus,
    bool? onlyAvailable,
    bool clearBloodGroup = false,
    bool clearDivision = false,
    bool clearZila = false,
    bool clearCampus = false,
  }) {
    return DonorSearchFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      bloodGroup: clearBloodGroup ? null : (bloodGroup ?? this.bloodGroup),
      division: clearDivision ? null : (division ?? this.division),
      zila: clearZila ? null : (zila ?? this.zila),
      campus: clearCampus ? null : (campus ?? this.campus),
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
    );
  }
}

class DonorSearchNotifier extends StateNotifier<List<DonorSearchResult>> {
  DonorSearchNotifier() : super(_initialDonors);

  static final List<DonorSearchResult> _initialDonors = [
    const DonorSearchResult(
      id: 'd1',
      name: 'Zahir Raihan',
      bloodGroup: 'A+',
      campusOrLocation: 'Dhaka Medical College',
      division: 'Dhaka',
      zila: 'Dhaka',
      lastDonationText: 'Donated: 6 months ago',
      isVerified: true,
      isAvailable: true,
      location: LatLng(23.7259, 90.3976),
      phone: '+8801711223344',
    ),
    const DonorSearchResult(
      id: 'd2',
      name: 'Anika Tabassum',
      bloodGroup: 'O+',
      campusOrLocation: 'BUET Campus',
      division: 'Dhaka',
      zila: 'Dhaka',
      lastDonationText: 'Last donation: 4 mos ago',
      isVerified: true,
      isAvailable: true,
      location: LatLng(23.7266, 90.3888),
      phone: '+8801811556677',
    ),
    const DonorSearchResult(
      id: 'd3',
      name: 'Md. Jalal',
      bloodGroup: 'B+',
      campusOrLocation: 'RUET Campus, Rajshahi',
      division: 'Rajshahi',
      zila: 'Rajshahi',
      lastDonationText: 'Last donation: 1 mo ago (Unavailable)',
      isVerified: false,
      isAvailable: false,
      location: LatLng(24.3636, 88.6284),
      phone: '+8801911998877',
    ),
    const DonorSearchResult(
      id: 'd4',
      name: 'Arifur Rahman',
      bloodGroup: 'O-',
      campusOrLocation: 'Chittagong Medical College',
      division: 'Chattogram',
      zila: 'Chattogram',
      lastDonationText: 'Donated: 5 months ago',
      isVerified: true,
      isAvailable: true,
      location: LatLng(22.3569, 91.8215),
      phone: '+8801611334455',
    ),
    const DonorSearchResult(
      id: 'd5',
      name: 'Farzana Haque',
      bloodGroup: 'AB+',
      campusOrLocation: 'Sylhet MAG Osmani Medical',
      division: 'Sylhet',
      zila: 'Sylhet',
      lastDonationText: 'Donated: 7 months ago',
      isVerified: true,
      isAvailable: true,
      location: LatLng(24.8949, 91.8687),
      phone: '+8801511223344',
    ),
  ];

  List<DonorSearchResult> filterDonors(DonorSearchFilter filter) {
    return state.where((donor) {
      if (filter.searchQuery.isNotEmpty) {
        final q = filter.searchQuery.toLowerCase();
        final match = donor.name.toLowerCase().contains(q) ||
            donor.campusOrLocation.toLowerCase().contains(q) ||
            donor.bloodGroup.toLowerCase().contains(q) ||
            donor.zila.toLowerCase().contains(q);
        if (!match) return false;
      }

      if (filter.bloodGroup != null && filter.bloodGroup!.isNotEmpty && filter.bloodGroup != 'Any') {
        if (donor.bloodGroup != filter.bloodGroup) return false;
      }

      if (filter.division != null && filter.division!.isNotEmpty) {
        if (donor.division != filter.division) return false;
      }

      if (filter.zila != null && filter.zila!.isNotEmpty && filter.zila != 'All Zilas') {
        if (donor.zila != filter.zila) return false;
      }

      if (filter.campus != null && filter.campus!.isNotEmpty && filter.campus != 'All Campuses') {
        if (!donor.campusOrLocation.toLowerCase().contains(filter.campus!.toLowerCase())) return false;
      }

      if (filter.onlyAvailable && !donor.isAvailable) {
        return false;
      }

      return true;
    }).toList();
  }
}

final donorSearchFilterProvider = StateProvider<DonorSearchFilter>((ref) {
  return const DonorSearchFilter();
});

final donorSearchProvider =
    StateNotifierProvider<DonorSearchNotifier, List<DonorSearchResult>>((ref) {
  return DonorSearchNotifier();
});

final filteredDonorsProvider = Provider<List<DonorSearchResult>>((ref) {
  final filter = ref.watch(donorSearchFilterProvider);
  final notifier = ref.watch(donorSearchProvider.notifier);
  return notifier.filterDonors(filter);
});
