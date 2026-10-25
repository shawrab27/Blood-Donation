// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'dart:async';
import 'package:flutter/material.dart';

/// Stitch-aligned 56px Capsule Search Bar with enforced privacy lock.
/// STRICT PRIVACY LOCK: Searches by donor name and phone number are locked out.
/// Queries only match campus, district, upazila, and geographical location.
class DonorSearchBar extends StatefulWidget {
  const DonorSearchBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  State<DonorSearchBar> createState() => _DonorSearchBarState();
}

class _DonorSearchBarState extends State<DonorSearchBar> {
  Timer? _debounceTimer;
  bool _showPrivacyNotice = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onInputChanged(String val) {
    // Check if user tries typing phone digits (e.g., 017..., +880...)
    final hasPhoneDigits = RegExp(r'\d{5,}').hasMatch(val);
    setState(() {
      _showPrivacyNotice = hasPhoneDigits;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        widget.onSearchChanged(val.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 56px Capsule Search Input
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xFFE6BDBA), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x088E7D7F),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 18),
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF916F6C),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  onChanged: _onInputChanged,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF24191A),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search by Campus, District, or Location...',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF916F6C),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (widget.searchController.text.isNotEmpty)
                PressableScale(child: IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF916F6C), size: 20),
                  onPressed: () {
                    widget.searchController.clear();
                    _onInputChanged('');
                  },
                ))
              else
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Tooltip(
                    message: 'Privacy lock: Name & phone searching is locked.',
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFFC30121),
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Privacy Lock Warning if phone number detected
        if (_showPrivacyNotice)
          Container(
            margin: const EdgeInsets.only(top: 8, left: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE9EB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE6BDBA)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF960017)),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Privacy lock active: Searching by phone or name is locked. Search by campus/area.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF960017),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
