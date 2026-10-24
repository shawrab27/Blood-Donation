// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.
// USER RULE - do not change

import 'package:flutter/material.dart';
import '../constants/bd_locations.dart';
import '../theme/app_colors.dart';

/// Shared Bangladesh Location Cascade Selector.
/// Single source of truth for Division -> District (Zila) -> Upazila cascading.
/// 
/// Key Guarantees:
/// 1. Zila -> Division cascade: Selecting a District automatically auto-populates its Division.
/// 2. Upazila list is never empty for any of Bangladesh's 64 districts (backed by canonical dataset).
/// 3. Standard BloodPulse capsule styling with border radius 50.
class LocationCascadeSelector extends StatefulWidget {
  const LocationCascadeSelector({
    super.key,
    this.initialDivision,
    this.initialDistrict,
    this.initialUpazila,
    required this.onChanged,
    this.showDivision = true,
    this.showDistrict = true,
    this.showUpazila = true,
    this.isDivisionRequired = false,
    this.isDistrictRequired = true,
    this.isUpazilaRequired = false,
    this.isBangla = false,
    this.enabled = true,
  });

  final String? initialDivision;
  final String? initialDistrict;
  final String? initialUpazila;
  final void Function(String? division, String? district, String? upazila) onChanged;
  final bool showDivision;
  final bool showDistrict;
  final bool showUpazila;
  final bool isDivisionRequired;
  final bool isDistrictRequired;
  final bool isUpazilaRequired;
  final bool isBangla;
  final bool enabled;

  @override
  State<LocationCascadeSelector> createState() => _LocationCascadeSelectorState();
}

class _LocationCascadeSelectorState extends State<LocationCascadeSelector> {
  String? _selectedDivision;
  String? _selectedDistrict;
  String? _selectedUpazila;

  @override
  void initState() {
    super.initState();
    _selectedDivision = widget.initialDivision;
    _selectedDistrict = widget.initialDistrict;
    _selectedUpazila = widget.initialUpazila;

    // Auto-resolve division if district was provided initially
    if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
      final div = getDivisionForDistrict(_selectedDistrict!);
      if (div != null) {
        _selectedDivision = div;
      }
    }
  }

  @override
  void didUpdateWidget(covariant LocationCascadeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDistrict != oldWidget.initialDistrict) {
      _selectedDistrict = widget.initialDistrict;
      if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
        _selectedDivision = getDivisionForDistrict(_selectedDistrict!) ?? _selectedDivision;
      }
    }
    if (widget.initialDivision != oldWidget.initialDivision) {
      _selectedDivision = widget.initialDivision;
    }
    if (widget.initialUpazila != oldWidget.initialUpazila) {
      _selectedUpazila = widget.initialUpazila;
    }
  }

  void _onDivisionChanged(String? division) {
    setState(() {
      _selectedDivision = division;
      // If selected district does not belong to new division, reset district & upazila
      if (_selectedDistrict != null) {
        final currentDiv = getDivisionForDistrict(_selectedDistrict!);
        if (currentDiv != division) {
          _selectedDistrict = null;
          _selectedUpazila = null;
        }
      }
    });
    widget.onChanged(_selectedDivision, _selectedDistrict, _selectedUpazila);
  }

  void _onDistrictChanged(String? district) {
    setState(() {
      _selectedDistrict = district;
      _selectedUpazila = null; // Reset upazila on district change
      if (district != null && district.isNotEmpty) {
        // Zila -> Division cascade
        final div = getDivisionForDistrict(district);
        if (div != null) {
          _selectedDivision = div;
        }
      }
    });
    widget.onChanged(_selectedDivision, _selectedDistrict, _selectedUpazila);
  }

  void _onUpazilaChanged(String? upazila) {
    setState(() {
      _selectedUpazila = upazila;
    });
    widget.onChanged(_selectedDivision, _selectedDistrict, _selectedUpazila);
  }

  List<String> get _availableDistricts {
    if (_selectedDivision != null && _selectedDivision!.isNotEmpty) {
      return getDistrictsForDivision(_selectedDivision!);
    }
    return kAllDistricts;
  }

  List<String> get _availableUpazilas {
    if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
      return getUpazilasForDistrict(_selectedDistrict!);
    }
    return const [];
  }

  InputDecoration _inputDecoration(String label, {bool isRequired = false}) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      labelStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        color: Color(0xFF666666),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(50),
        borderSide: const BorderSide(color: Color(0xFFF3F4F6), width: 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBn = widget.isBangla;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showDivision) ...[
          DropdownButtonFormField<String>(
            value: _selectedDivision,
            isExpanded: true,
            decoration: _inputDecoration(
              isBn ? 'বিভাগ' : 'Division',
              isRequired: widget.isDivisionRequired,
            ),
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF666666)),
            items: kDivisions.map((div) {
              return DropdownMenuItem<String>(
                value: div,
                child: Text(
                  div,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: widget.enabled ? _onDivisionChanged : null,
          ),
          const SizedBox(height: 12),
        ],
        if (widget.showDistrict) ...[
          DropdownButtonFormField<String>(
            value: _availableDistricts.contains(_selectedDistrict) ? _selectedDistrict : null,
            isExpanded: true,
            decoration: _inputDecoration(
              isBn ? 'জেলা' : 'District (Zila)',
              isRequired: widget.isDistrictRequired,
            ),
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF666666)),
            items: _availableDistricts.map((dist) {
              return DropdownMenuItem<String>(
                value: dist,
                child: Text(
                  dist,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: widget.enabled ? _onDistrictChanged : null,
            validator: widget.isDistrictRequired
                ? (v) => (v == null || v.isEmpty)
                    ? (isBn ? 'জেলা নির্বাচন করুন' : 'District is required')
                    : null
                : null,
          ),
          const SizedBox(height: 12),
        ],
        if (widget.showUpazila) ...[
          DropdownButtonFormField<String>(
            value: _availableUpazilas.contains(_selectedUpazila) ? _selectedUpazila : null,
            isExpanded: true,
            decoration: _inputDecoration(
              isBn ? 'উপজেলা' : 'Upazila',
              isRequired: widget.isUpazilaRequired,
            ),
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF666666)),
            items: _availableUpazilas.map((upz) {
              return DropdownMenuItem<String>(
                value: upz,
                child: Text(
                  upz,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (widget.enabled && _selectedDistrict != null)
                ? _onUpazilaChanged
                : null,
            validator: widget.isUpazilaRequired
                ? (v) => (v == null || v.isEmpty)
                    ? (isBn ? 'উপজেলা নির্বাচন করুন' : 'Upazila is required')
                    : null
                : null,
          ),
        ],
      ],
    );
  }
}
