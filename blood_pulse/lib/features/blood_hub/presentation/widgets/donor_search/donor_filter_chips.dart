// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../data/blood_hub_api_service.dart';

const List<String> _kBloodGroups = [
  'Any', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
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

/// Filter chips row for Blood Group, Division, Zila, Campus, and Advanced (Map toggle).
class DonorFilterChips extends StatelessWidget {
  const DonorFilterChips({
    super.key,
    required this.currentFilter,
    required this.onBloodGroupSelected,
    required this.onDivisionSelected,
    required this.onDistrictSelected,
    required this.isMapVisible,
    required this.onToggleMap,
  });

  final DonorSearchFilter currentFilter;
  final ValueChanged<String?> onBloodGroupSelected;
  final ValueChanged<String?> onDivisionSelected;
  final ValueChanged<String?> onDistrictSelected;
  final bool isMapVisible;
  final VoidCallback onToggleMap;

  @override
  Widget build(BuildContext context) {
    final bgLabel = currentFilter.bloodGroup ?? 'Blood Group';
    final isBgSelected = currentFilter.bloodGroup != null && currentFilter.bloodGroup != 'Any';

    final divLabel = currentFilter.division ?? 'Division';
    final isDivSelected = currentFilter.division != null;

    final distLabel = currentFilter.district ?? 'Zila';
    final isDistSelected = currentFilter.district != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Blood Group Chip
          _FilterChipButton(
            label: bgLabel,
            isSelected: isBgSelected,
            icon: Icons.water_drop_outlined,
            onTap: () => _showBloodGroupSheet(context),
          ),
          const SizedBox(width: 8),

          // 2. Division Chip
          _FilterChipButton(
            label: divLabel,
            isSelected: isDivSelected,
            icon: Icons.map_outlined,
            onTap: () => _showDivisionSheet(context),
          ),
          const SizedBox(width: 8),

          // 3. Zila / District Chip
          _FilterChipButton(
            label: distLabel,
            isSelected: isDistSelected,
            icon: Icons.location_city_outlined,
            onTap: () => _showDistrictSheet(context),
          ),
          const SizedBox(width: 8),

          // 4. Advanced / Map Toggle Chip
          _FilterChipButton(
            label: isMapVisible ? 'Hide Map' : 'Map View',
            isSelected: isMapVisible,
            icon: Icons.tune_rounded,
            highlightColor: const Color(0xFF0D68AA),
            onTap: onToggleMap,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Blood Group',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                      selectedColor: const Color(0xFFC30121),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF2B2B2B),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('All Divisions'),
                selected: currentFilter.division == null,
                onTap: () {
                  Navigator.pop(ctx);
                  onDivisionSelected(null);
                },
              ),
              ..._kDivisionDistricts.keys.map(
                (div) => ListTile(
                  title: Text(div),
                  selected: currentFilter.division == div,
                  onTap: () {
                    Navigator.pop(ctx);
                    onDivisionSelected(div);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDistrictSheet(BuildContext context) {
    final districts = currentFilter.division != null
        ? (_kDivisionDistricts[currentFilter.division!] ?? [])
        : _kDivisionDistricts.values.expand((d) => d).toList();

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
                  'Select District / Zila',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('All Districts'),
                selected: currentFilter.district == null,
                onTap: () {
                  Navigator.pop(ctx);
                  onDistrictSelected(null);
                },
              ),
              ...districts.map(
                (dist) => ListTile(
                  title: Text(dist),
                  selected: currentFilter.district == dist,
                  onTap: () {
                    Navigator.pop(ctx);
                    onDistrictSelected(dist);
                  },
                ),
              ),
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
    required this.icon,
    required this.onTap,
    this.highlightColor,
  });

  final String label;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = highlightColor ?? const Color(0xFFC30121);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE8DADA),
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
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF5F5E5E),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF5F5E5E),
            ),
          ],
        ),
      ),
    );
  }
}
