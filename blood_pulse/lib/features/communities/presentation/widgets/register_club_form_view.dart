import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../domain/providers/communities_provider.dart';

class RegisterClubFormView extends ConsumerStatefulWidget {
  const RegisterClubFormView({super.key});

  @override
  ConsumerState<RegisterClubFormView> createState() =>
      _RegisterClubFormViewState();
}

class _RegisterClubFormViewState extends ConsumerState<RegisterClubFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _presidentCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int? _selectedDivisionId;
  int? _selectedDistrictId;
  int? _selectedUpazilaId;

  bool _agreedToLifetime = false;
  bool _isSubmitting = false;

  static const String _baseUrl = 'https://bloodpulse-backend.onrender.com/api';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sloganCtrl.dispose();
    _yearCtrl.dispose();
    _presidentCtrl.dispose();
    _contactCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToLifetime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the commitment condition.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'president_name': _presidentCtrl.text.trim(),
        'contact_number': _contactCtrl.text.trim(),
        if (_sloganCtrl.text.isNotEmpty) 'slogan': _sloganCtrl.text.trim(),
        if (_yearCtrl.text.isNotEmpty) 'established_year': int.tryParse(_yearCtrl.text),
        if (_selectedDivisionId != null) 'division': _selectedDivisionId,
        if (_selectedDistrictId != null) 'district': _selectedDistrictId,
        if (_selectedUpazilaId != null) 'upazila': _selectedUpazilaId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/clubs/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _showSuccessDialog(data['club_name'] ?? _nameCtrl.text);
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${err['errors'] ?? response.statusCode}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(String clubName) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFFF3DDE0), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 36),
        ),
        title: const Text(
          'Application Submitted!',
          style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, color: AppColors.secondary),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '"$clubName" has been submitted for admin review. You\'ll be notified once it\'s approved.',
          style: const TextStyle(fontFamily: 'Inter', color: AppColors.neutral, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: CapsuleButton(
              label: 'Go Back',
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final divisionsAsync = ref.watch(divisionsProvider);
    final districtsAsync = ref.watch(districtsProvider(_selectedDivisionId));
    final upazilasAsync = ref.watch(upazilasProvider(_selectedDistrictId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BloodPulseAppBar(
        showBackButton: true,
        showLogo: false,
        subtitle: 'Register Local Club',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC30121), Color(0xFF8B000E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.groups_rounded, color: Colors.white70, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Register Your Club',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Join the BloodPulse network and bring your community together for a lifesaving cause.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Section: Club Info
              _SectionLabel(label: 'Club Information'),
              const SizedBox(height: 12),

              CustomInputField(
                controller: _nameCtrl,
                label: 'Club Name',
                hint: 'e.g. Dhaka Blood Warriors',
                prefixIcon: Icons.groups_rounded,
                validator: (val) => (val == null || val.isEmpty) ? 'Club name is required' : null,
              ),
              const SizedBox(height: 14),

              CustomInputField(
                controller: _sloganCtrl,
                label: 'Slogan (Optional)',
                hint: 'Your club\'s motto or tagline',
                prefixIcon: Icons.format_quote_rounded,
              ),
              const SizedBox(height: 14),

              CustomInputField(
                controller: _yearCtrl,
                label: 'Established Year (Optional)',
                hint: 'e.g. 2019',
                prefixIcon: Icons.calendar_today_rounded,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return null;
                  final year = int.tryParse(val);
                  if (year == null || year < 1900 || year > 2030) return 'Enter a valid year';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              CustomInputField(
                controller: _descCtrl,
                label: 'Club Description',
                hint: 'Tell us about your activities and mission...',
                prefixIcon: Icons.description_rounded,
                maxLines: 4,
                validator: (val) => (val == null || val.isEmpty) ? 'Description is required' : null,
              ),
              const SizedBox(height: 24),

              // Section: Location
              _SectionLabel(label: 'Club Location'),
              const SizedBox(height: 12),

              divisionsAsync.when(
                loading: () => const LinearProgressIndicator(color: AppColors.primary),
                error: (e, _) => Text('Could not load divisions: $e'),
                data: (divisions) => DropdownButtonFormField<int>(
                  initialValue: _selectedDivisionId,
                  decoration: _dropdownDecoration('Division'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Select Division', style: TextStyle(fontFamily: 'Inter'))),
                    ...divisions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontFamily: 'Inter')))),
                  ],
                  onChanged: (val) => setState(() {
                    _selectedDivisionId = val;
                    _selectedDistrictId = null;
                    _selectedUpazilaId = null;
                  }),
                ),
              ),
              const SizedBox(height: 12),

              if (_selectedDivisionId != null)
                districtsAsync.when(
                  loading: () => const LinearProgressIndicator(color: AppColors.primary),
                  error: (e, _) => Text('Error: $e'),
                  data: (districts) => DropdownButtonFormField<int>(
                    initialValue: _selectedDistrictId,
                    decoration: _dropdownDecoration('District'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select District', style: TextStyle(fontFamily: 'Inter'))),
                      ...districts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontFamily: 'Inter')))),
                    ],
                    onChanged: (val) => setState(() {
                      _selectedDistrictId = val;
                      _selectedUpazilaId = null;
                    }),
                  ),
                ),

              if (_selectedDistrictId != null) ...[
                const SizedBox(height: 12),
                upazilasAsync.when(
                  loading: () => const LinearProgressIndicator(color: AppColors.primary),
                  error: (e, _) => Text('Error: $e'),
                  data: (upazilas) => DropdownButtonFormField<int>(
                    initialValue: _selectedUpazilaId,
                    decoration: _dropdownDecoration('Upazila'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select Upazila', style: TextStyle(fontFamily: 'Inter'))),
                      ...upazilas.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name, style: const TextStyle(fontFamily: 'Inter')))),
                    ],
                    onChanged: (val) => setState(() => _selectedUpazilaId = val),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Section: Leader Info
              _SectionLabel(label: 'Leader / President Details'),
              const SizedBox(height: 12),

              CustomInputField(
                controller: _presidentCtrl,
                label: 'President / Leader Name',
                hint: 'Full name',
                prefixIcon: Icons.person_rounded,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              CustomInputField(
                controller: _contactCtrl,
                label: 'Contact Number',
                hint: '+880 1XXXXXXXXX',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 28),

              // Commitment checkbox
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _agreedToLifetime ? AppColors.primary : Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreedToLifetime,
                      onChanged: (val) => setState(() => _agreedToLifetime = val ?? false),
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'I confirm that this club is dedicated to voluntary blood donation and committed to a long-term mission of saving lives.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: _isSubmitting
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : CapsuleButton(
                        label: 'Submit Application',
                        onPressed: _submit,
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
      ],
    );
  }
}
