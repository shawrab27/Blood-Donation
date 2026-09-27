import sys

with open('lib/features/auth/presentation/screens/registration_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Imports
if 'package:flutter_typeahead/flutter_typeahead.dart' not in text:
    text = text.replace('import \'package:flutter_riverpod/flutter_riverpod.dart\';', 'import \'package:flutter_riverpod/flutter_riverpod.dart\';\nimport \'package:flutter_typeahead/flutter_typeahead.dart\';\nimport \'package:blood_pulse/services/api_client.dart\';')

# 2. State vars
text = text.replace('    String? _bloodGroup;', '    String? _bloodGroup;\n    String? _selectedInstitutionId;\n    String? _selectedUpazilaId;\n    bool _manualInstitution = false;\n    final _apiClient = ApiClient();')

# 3. catDetails logic
cat_student_replace = \"\"\"      if (_category == _UserCategory.student) {
      if (_selectedInstitutionId != null) {
        catDetails['institution_id'] = _selectedInstitutionId!;
      } else {
        catDetails['institute'] = _instituteCtrl.text.trim();
      }
\"\"\"
text = text.replace('      if (_category == _UserCategory.student) {\\n        catDetails[\\'institute\\'] = _instituteCtrl.text.trim();', cat_student_replace)

cat_civilian_replace = \"\"\"      } else {
        catDetails['division'] = _selectedDivision ?? 'Dhaka';
        catDetails['district'] = _selectedZila ?? 'Dhaka';
        if (_selectedUpazilaId != null) {
          catDetails['upazila_id'] = _selectedUpazilaId!;
        } else {
          catDetails['upazila'] = _upazilaCtrl.text.trim();
        }\"\"\"
text = text.replace('      } else {\\n        catDetails[\\'division\\'] = _selectedDivision ?? \\'Dhaka\\';\\n        catDetails[\\'district\\'] = _selectedZila ?? \\'Dhaka\\';\\n        catDetails[\\'upazila\\'] = _upazilaCtrl.text.trim();', cat_civilian_replace)

with open('lib/features/auth/presentation/screens/registration_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
