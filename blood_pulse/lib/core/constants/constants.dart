// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

class Constants {
  // Verified hotlines. Verify periodically. Do not invent any other numbers.
  static const List<Map<String, dynamic>> verifiedHotlines = [
    {
      'title': 'National Emergency',
      'number': '999',
      'subtitle': 'Police, Fire, and Ambulance (24/7)',
      'icon': Icons.local_police_rounded,
    },
    {
      'title': 'Fire Service',
      'number': '16163',
      'subtitle': 'Emergency Rescue & Ambulance',
      'icon': Icons.fire_truck_rounded,
    },
    {
      'title': 'National Health Helpline',
      'number': '16263',
      'subtitle': 'Health queries and doctor consultations',
      'icon': Icons.medical_services_rounded,
    },
  ];
}
