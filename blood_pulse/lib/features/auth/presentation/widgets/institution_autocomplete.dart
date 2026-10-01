// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project â€” unauthorized copying or distribution prohibited.

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/custom_input_field.dart';
import '../../../../services/api_client.dart';

/// A typeahead autocomplete widget for institutions backed by BANBEIS data.
///
/// Features:
///   â€¢ 350ms debounce
///   â€¢ Minimum 2 characters before querying API
///   â€¢ In-flight request cancellation (stale responses discarded)
///   â€¢ Capsule styling matching BloodPulse design system
///   â€¢ Clear button (X) to reset the field
///   â€¢ Type badge + District display in suggestion dropdown
///   â€¢ Free-text fallback when no results or on API error
class InstitutionAutocomplete extends StatefulWidget {
  const InstitutionAutocomplete({
    super.key,
    required this.controller,
    required this.onSelected,
    this.validator,
    this.apiClient,
    this.hint = 'Search institution or university...',
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<Map<String, dynamic>?> onSelected;
  final String? Function(String?)? validator;
  final ApiClient? apiClient;
  final String hint;
  final bool enabled;

  @override
  State<InstitutionAutocomplete> createState() => _InstitutionAutocompleteState();
}

class _InstitutionAutocompleteState extends State<InstitutionAutocomplete> {
  late final ApiClient _apiClient;
  int _searchSeq = 0;
  Map<String, dynamic>? _selectedItem;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // If the text was changed away from the selected item's name, reset selected ID to null (free-text mode)
    if (_selectedItem != null && widget.controller.text.trim() != (_selectedItem!['name'] ?? '').toString().trim()) {
      _selectedItem = null;
      widget.onSelected(null);
    }
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _fetchSuggestions(String pattern) async {
    final query = pattern.trim();
    if (query.length < 2) return [];

    _debounceTimer?.cancel();
    final completer = Completer<List<Map<String, dynamic>>>();

    final currentSeq = ++_searchSeq;
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _apiClient.searchInstitutions(query);
        if (currentSeq == _searchSeq && !completer.isCompleted) {
          completer.complete(results);
        } else if (!completer.isCompleted) {
          completer.complete([]);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      }
    });

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Map<String, dynamic>>(
      controller: widget.controller,
      debounceDuration: Duration.zero,
      suggestionsCallback: _fetchSuggestions,

      builder: (context, controller, focusNode) {
        final hasText = controller.text.isNotEmpty;
        return CustomInputField(
          controller: controller,
          focusNode: focusNode,
          hint: widget.hint,
          prefixIcon: Icons.school_outlined,
          enabled: widget.enabled,
          validator: widget.validator,
          suffixWidget: hasText
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF757575),
                  ),
                  splashRadius: 18,
                  onPressed: () {
                    controller.clear();
                    _selectedItem = null;
                    widget.onSelected(null);
                    setState(() {});
                  },
                )
              : null,
        );
      },
      itemBuilder: (context, suggestion) {
        final name = suggestion['name']?.toString() ?? '';
        final itype = suggestion['institution_type']?.toString() ?? '';
        final district = suggestion['district_name']?.toString() ?? '';
        final eiin = suggestion['eiin']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDF3F3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 18,
                  color: Color(0xFFC30121),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2B2B2B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (district.isNotEmpty) ...[
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF757575),
                          ),
                          Text(
                            district,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF757575),
                            ),
                          ),
                        ],
                        if (district.isNotEmpty && eiin.isNotEmpty)
                          const Text('â€¢', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 10)),
                        if (eiin.isNotEmpty)
                          Text(
                            'EIIN: $eiin',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF9E9E9E),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (itype.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF3F3),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Text(
                    itype.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC30121),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      decorationBuilder: (context, child) {
        return Material(
          type: MaterialType.card,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          shadowColor: Colors.black26,
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      onSelected: (suggestion) {
        _selectedItem = suggestion;
        widget.controller.text = suggestion['name']?.toString() ?? '';
        widget.onSelected(suggestion);
        setState(() {});
      },
      emptyBuilder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFF757575)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No institutions found. You can keep what you typed.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF757575),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
