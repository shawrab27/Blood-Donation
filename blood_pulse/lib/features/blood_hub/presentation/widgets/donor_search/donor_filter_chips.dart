// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../data/blood_hub_api_service.dart';

const List<String> _kBloodGroups = [
  'Any', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
];

const List<String> _kTopCampuses = [
  'All Campuses',
  'Dhaka Medical College',
  'BUET Campus',
  'Dhaka University',
  'North South University',
  'IUT',
  'Chittagong Medical College',
  'Mirpur, Dhaka',
  'Mymensingh Medical College',
  'Rajshahi Medical College',
  'Sylhet MAG Osmani Medical College',
];

const Map<String, List<String>> _kDivisionDistricts = {
  'Dhaka': ['Dhaka', 'Gazipur', 'Narayanganj', 'Tangail', 'Faridpur', 'Manikganj', 'Munshiganj', 'Narsingdi', 'Gopalganj', 'Kishoreganj', 'Madaripur', 'Rajbari', 'Shariatpur'],
  'Chattogram': ['Chattogram', "Cox's Bazar", 'Cumilla', 'Feni', 'Brahmanbaria', 'Chandpur', 'Noakhali', 'Lakshmipur', 'Khagrachhari', 'Rangamati', 'Bandarban'],
  'Rajshahi': ['Rajshahi', 'Bogura', 'Pabna', 'Sirajganj', 'Naogaon', 'Natore', 'Chapai Nawabganj', 'Joypurhat'],
  'Khulna': ['Khulna', 'Jashore', 'Kushtia', 'Satkhira', 'Bagerhat', 'Chuadanga', 'Jhenaidah', 'Magura', 'Meherpur', 'Narail'],
  'Barishal': ['Barishal', 'Bhola', 'Jhalokati', 'Patuakhali', 'Pirojpur', 'Barguna'],
  'Sylhet': ['Sylhet', 'Moulvibazar', 'Habiganj', 'Sunamganj'],
  'Rangpur': ['Rangpur', 'Dinajpur', 'Kurigram', 'Gaibandha', 'Nilphamari', 'Panchagarh', 'Thakurgaon', 'Lalmonirhat'],
  'Mymensingh': ['Mymensingh', 'Jamalpur', 'Netrokona', 'Sherpur'],
};

/// Filter chips row for Blood Group, Campus, Division, and Zila matching Stitch UI.
class DonorFilterChips extends StatelessWidget {
  const DonorFilterChips({
    super.key,
    required this.currentFilter,
    required this.onBloodGroupSelected,
    this.onCampusSelected,
    required this.onDivisionSelected,
    required this.onDistrictSelected,
    required this.onResetFilters,
  });

  final DonorSearchFilter currentFilter;
  final ValueChanged<String?> onBloodGroupSelected;
  final ValueChanged<String?>? onCampusSelected;
  final ValueChanged<String?> onDivisionSelected;
  final ValueChanged<String?> onDistrictSelected;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final bgLabel = currentFilter.bloodGroup ?? 'Blood Group';
    final isBgSelected = currentFilter.bloodGroup != null && currentFilter.bloodGroup != 'Any';

    final campusLabel = currentFilter.campus ?? 'Campus';
    final isCampusSelected = currentFilter.campus != null && currentFilter.campus != 'All Campuses';

    final divLabel = currentFilter.division ?? 'Division';
    final isDivSelected = currentFilter.division != null && currentFilter.division != 'Any';

    final distLabel = currentFilter.district ?? 'Zila';
    final isDistSelected = currentFilter.district != null && currentFilter.district != 'Any';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Blood Group Chip (active crimson when selected)
          _FilterChipButton(
            label: bgLabel,
            isSelected: isBgSelected,
            onTap: () => _showBloodGroupSheet(context),
          ),
          const SizedBox(width: 8),

          // 2. Division Chip
          _FilterChipButton(
            label: divLabel,
            isSelected: isDivSelected,
            onTap: () => _showDivisionSheet(context),
          ),
          const SizedBox(width: 8),

          // 4. Zila / District Chip
          _FilterChipButton(
            label: distLabel,
            isSelected: isDistSelected,
            onTap: () => _showDistrictSheet(context),
          ),
          const SizedBox(width: 8),

          // 5. Reset Filter Button
          if (isBgSelected || isDivSelected || isDistSelected)
            InkWell(
              onTap: onResetFilters,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: const Color(0xFFE6BDBA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.close_rounded, size: 16, color: Color(0xFF960017)),
                    SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF960017),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showBloodGroupSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Blood Group',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _kBloodGroups.map((bg) {
                    final isSel = (bg == 'Any' && currentFilter.bloodGroup == null) ||
                        currentFilter.bloodGroup == bg;
                    return ChoiceChip(
                      label: Text(bg),
                      selected: isSel,
                      selectedColor: const Color(0xFF960017),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                        side: BorderSide(
                          color: isSel ? const Color(0xFF960017) : const Color(0xFFE6BDBA),
                        ),
                      ),
                      labelStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: isSel ? Colors.white : const Color(0xFF24191A),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) {
                        Navigator.pop(ctx);
                        onBloodGroupSelected(bg == 'Any' ? null : bg);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCampusSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Select Campus or Area',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
              ),
              ..._kTopCampuses.map((camp) {
                final isSel = currentFilter.campus == camp ||
                    (camp == 'All Campuses' && currentFilter.campus == null);
                return ListTile(
                  title: Text(
                    camp,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? const Color(0xFF960017) : const Color(0xFF24191A),
                    ),
                  ),
                  trailing: isSel ? const Icon(Icons.check, color: Color(0xFF960017)) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onCampusSelected?.call(camp == 'All Campuses' ? null : camp);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showDivisionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Select Division',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
              ),
              ListTile(
                title: const Text('All Divisions'),
                onTap: () {
                  Navigator.pop(ctx);
                  onDivisionSelected(null);
                },
              ),
              ..._kDivisionDistricts.keys.map((div) {
                final isSel = currentFilter.division == div;
                return ListTile(
                  title: Text(
                    div,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? const Color(0xFF960017) : const Color(0xFF24191A),
                    ),
                  ),
                  trailing: isSel ? const Icon(Icons.check, color: Color(0xFF960017)) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onDivisionSelected(div);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showDistrictSheet(BuildContext context) {
    final div = currentFilter.division;
    final districts = div != null && _kDivisionDistricts.containsKey(div)
        ? _kDivisionDistricts[div]!
        : _kDivisionDistricts.values.expand((d) => d).toSet().toList()..sort();

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  div != null ? 'Select Zila in $div' : 'Select Zila',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
              ),
              ListTile(
                title: const Text('All Zilas'),
                onTap: () {
                  Navigator.pop(ctx);
                  onDistrictSelected(null);
                },
              ),
              ...districts.map((dist) {
                final isSel = currentFilter.district == dist;
                return ListTile(
                  title: Text(
                    dist,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? const Color(0xFF960017) : const Color(0xFF24191A),
                    ),
                  ),
                  trailing: isSel ? const Icon(Icons.check, color: Color(0xFF960017)) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onDistrictSelected(dist);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF960017) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF960017) : const Color(0xFFE6BDBA),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF5C3F3D),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF5C3F3D),
            ),
          ],
        ),
      ),
    );
  }
}
