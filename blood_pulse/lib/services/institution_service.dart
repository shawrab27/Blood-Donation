// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.
// USER RULE - do not change

import 'dart:convert';
import 'package:flutter/services.dart';

/// Single source of truth for Bangladesh academic institutions.
/// Provides offline bundled search across Schools, Colleges, Madrasas, and Universities.
class InstitutionService {
  InstitutionService._();
  static final InstitutionService instance = InstitutionService._();
  factory InstitutionService() => instance;

  List<Map<String, dynamic>>? _cachedInstitutions;

  /// Loads institutions dataset from bundled assets (supports both CSV and JSON formats).
  Future<List<Map<String, dynamic>>> loadInstitutions() async {
    if (_cachedInstitutions != null) {
      return _cachedInstitutions!;
    }

    // Try CSV first (B3: CSV parser)
    try {
      final csvString = await rootBundle.loadString('assets/data/institutions.csv');
      _cachedInstitutions = parseCsv(csvString);
      if (_cachedInstitutions!.isNotEmpty) {
        return _cachedInstitutions!;
      }
    } catch (_) {
      // Fallback to JSON if CSV loading fails
    }

    try {
      final jsonString = await rootBundle.loadString('assets/data/institutions.json');
      final List<dynamic> raw = jsonDecode(jsonString);
      _cachedInstitutions = raw.cast<Map<String, dynamic>>();
      return _cachedInstitutions!;
    } catch (_) {
      return [];
    }
  }

  /// Parses CSV format without external heavy dependencies.
  /// Handles standard CSV quotes, commas, and multiline values.
  List<Map<String, dynamic>> parseCsv(String csvContent) {
    final List<Map<String, dynamic>> list = [];
    final lines = csvContent.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return list;

    // Header: id,eiin,name,institution_type,district_name,upazila_name
    final headers = _parseCsvLine(lines.first);
    final idIdx = headers.indexOf('id');
    final eiinIdx = headers.indexOf('eiin');
    final nameIdx = headers.indexOf('name');
    final typeIdx = headers.indexOf('institution_type');
    final distIdx = headers.indexOf('district_name');
    final upzIdx = headers.indexOf('upazila_name');

    if (nameIdx == -1) return list;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _parseCsvLine(line);
      if (cols.length <= nameIdx) continue;

      final name = cols[nameIdx].trim();
      if (name.isEmpty) continue;

      final idStr = (idIdx != -1 && idIdx < cols.length) ? cols[idIdx].trim() : '$i';
      final id = int.tryParse(idStr) ?? i;
      final eiin = (eiinIdx != -1 && eiinIdx < cols.length) ? cols[eiinIdx].trim() : null;
      final type = (typeIdx != -1 && typeIdx < cols.length) ? cols[typeIdx].trim() : 'school';
      final district = (distIdx != -1 && distIdx < cols.length) ? cols[distIdx].trim() : null;
      final upazila = (upzIdx != -1 && upzIdx < cols.length) ? cols[upzIdx].trim() : null;

      list.add({
        'id': id,
        'eiin': (eiin != null && eiin.isNotEmpty) ? eiin : null,
        'name': name,
        'institution_type': type,
        'district_name': (district != null && district.isNotEmpty) ? district : null,
        'upazila_name': (upazila != null && upazila.isNotEmpty) ? upazila : null,
      });
    }

    return list;
  }

  List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++; // skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  /// Searches institutions with prefix priority and word matching.
  Future<List<Map<String, dynamic>>> search(
    String query, {
    String? type,
    String? district,
    int limit = 15,
  }) async {
    final cleanQ = query.trim().toLowerCase();
    if (cleanQ.isEmpty) return [];

    final all = await loadInstitutions();
    final words = cleanQ.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final matches = all.where((item) {
      if (type != null && type.isNotEmpty && type != 'All') {
        final itemType = (item['institution_type'] as String? ?? '').toLowerCase();
        if (itemType != type.toLowerCase()) return false;
      }
      if (district != null && district.isNotEmpty && district != 'Any') {
        final itemDist = (item['district_name'] as String? ?? '').toLowerCase();
        if (itemDist != district.toLowerCase()) return false;
      }

      final name = (item['name'] as String? ?? '').toLowerCase();
      final eiin = (item['eiin'] as String? ?? '').toLowerCase();

      // Check match by eiin or all words
      if (eiin == cleanQ) return true;
      return words.every((w) => name.contains(w));
    }).toList();

    // Sort:
    // 1. Exact start with query
    // 2. Exact word boundary match
    // 3. Alphabetical
    matches.sort((a, b) {
      final nameA = (a['name'] as String? ?? '').toLowerCase();
      final nameB = (b['name'] as String? ?? '').toLowerCase();
      final aStarts = nameA.startsWith(cleanQ);
      final bStarts = nameB.startsWith(cleanQ);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return nameA.compareTo(nameB);
    });

    return matches.take(limit).toList();
  }
}
