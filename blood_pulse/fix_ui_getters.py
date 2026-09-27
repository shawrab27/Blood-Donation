import os

filepath = 'lib/features/health_hub/domain/models/health_accessory_model.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add the UI properties as getters to the HealthAccessory class
ui_getters = '''
  String get tier => 'Curated Pick';
  double get rating => 4.8;
  int get reviewsCount => 150;
  
  IconData get icon {
    switch (category) {
      case 'Diagnostic & Clinic': return Icons.monitor_heart_outlined;
      case 'Consumables': return Icons.biotech_outlined;
      case 'Parts & Kits': return Icons.build_circle_outlined;
      case 'Donor Gear': return Icons.stars_outlined;
      default: return Icons.medical_services_outlined;
    }
  }

  Color get accentColor {
    switch (category) {
      case 'Diagnostic & Clinic': return const Color(0xFF0D68AA);
      case 'Consumables': return const Color(0xFFE65100);
      case 'Parts & Kits': return const Color(0xFF6A1B9A);
      case 'Donor Gear': return const Color(0xFFC30121);
      default: return const Color(0xFF1B8A4E);
    }
  }

  Color get bgLightColor {
    switch (category) {
      case 'Diagnostic & Clinic': return const Color(0xFFEDF4FF);
      case 'Consumables': return const Color(0xFFFFF3E0);
      case 'Parts & Kits': return const Color(0xFFF3E5F5);
      case 'Donor Gear': return const Color(0xFFFFF0F1);
      default: return const Color(0xFFE8F5E9);
    }
  }
}
'''
content = content.replace("}\n", ui_getters)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
