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
  ConsumerState<RegisterClubFormView> createState() => _RegisterClubFormViewState();
}

class _RegisterClubFormViewState extends ConsumerState<RegisterClubFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _presidentCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  int? _selectedDivisionId;
  int? _selectedUpazilaId;

  bool _isSubmitting = false;
  static const String _baseUrl = 'https://bloodpulse-proxy.vercel.app/api';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yearCtrl.dispose();
    _sloganCtrl.dispose();
    _descCtrl.dispose();
    _presidentCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDivisionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Division.')),
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
        'division': _selectedDivisionId,
        if (_selectedUpazilaId != null) 'upazila': _selectedUpazilaId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/clubs/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 48),
            title: const Text(
              'Application Submitted!',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold),
            ),
            content: Text(
              '"${_nameCtrl.text.trim()}" has been submitted for admin verification. Once verified, it will appear in the directory.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', color: AppColors.neutral),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: CapsuleButton(
                  label: 'Done',
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pop();
                  },
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed (${response.statusCode}). Please try again.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final divisionsAsync = ref.watch(divisionsProvider);
    final upazilasAsync = ref.watch(upazilasProvider(null));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BloodPulseAppBar(
        showBackButton: true,
        subtitle: 'Register Your Club',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Subtitle
              const Text(
                'Register Your Club',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Submit your local blood donation club to our directory. All submissions are reviewed by our medical admins before appearing publicly to ensure community trust and clinical reliability.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.neutral,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // ── Section 1: Basic Information ───────────────────────────────
              const _FormSectionTitle(title: 'Basic Information'),
              const SizedBox(height: 12),

              // Club Logo (Optional) upload slot
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Club Logo (Optional)',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Tap to upload logo • PNG or JPG, max 2MB',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.neutral),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              CustomInputField(
                controller: _nameCtrl,
                label: 'Club Name *',
                hint: 'e.g. LifeSavers Dhaka',
                prefixIcon: Icons.groups_rounded,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              CustomInputField(
                controller: _yearCtrl,
                label: 'Year Established',
                hint: 'YYYY',
                prefixIcon: Icons.calendar_today_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              CustomInputField(
                controller: _sloganCtrl,
                label: 'Club Slogan / Motto',
                hint: 'e.g. Give Blood, Give Life',
                prefixIcon: Icons.format_quote_rounded,
              ),
              const SizedBox(height: 12),

              CustomInputField(
                controller: _descCtrl,
                label: 'About the Club *',
                hint: "Describe your club's mission and regular activities...",
                prefixIcon: Icons.description_rounded,
                maxLines: 4,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 28),

              // ── Section 2: Contact & Location ──────────────────────────────
              const _FormSectionTitle(title: 'Contact & Location'),
              const SizedBox(height: 12),

              CustomInputField(
                controller: _presidentCtrl,
                label: 'President / Leader Name *',
                hint: 'Full Name',
                prefixIcon: Icons.person_rounded,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Leader Photo (Optional)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDE8E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.file_upload_outlined, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Leader Photo (Optional)', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                          Text('Upload Photo (JPG or PNG, max 5MB)', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              CustomInputField(
                controller: _contactCtrl,
                label: 'Contact Number *',
                hint: '+880...',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Division * Dropdown
              divisionsAsync.when(
                loading: () => const LinearProgressIndicator(color: AppColors.primary),
                error: (err, _) => const SizedBox.shrink(),
                data: (divisions) => DropdownButtonFormField<int>(
                  initialValue: _selectedDivisionId,
                  decoration: InputDecoration(
                    labelText: 'Division *',
                    labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    prefixIcon: const Icon(Icons.location_city_rounded, color: AppColors.neutral),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(50)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: divisions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                  onChanged: (val) => setState(() => _selectedDivisionId = val),
                  validator: (val) => val == null ? 'Please select a Division' : null,
                ),
              ),
              const SizedBox(height: 12),

              // Upazila Dropdown
              upazilasAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (err, _) => const SizedBox.shrink(),
                data: (upazilas) => DropdownButtonFormField<int>(
                  initialValue: _selectedUpazilaId,
                  decoration: InputDecoration(
                    labelText: 'Upazila',
                    labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    prefixIcon: const Icon(Icons.map_rounded, color: AppColors.neutral),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(50)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: upazilas.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                  onChanged: (val) => setState(() => _selectedUpazilaId = val),
                ),
              ),
              const SizedBox(height: 28),

              // ── Section 3: Media & Verification Documents ──────────────────
              const _FormSectionTitle(title: 'Media & Verification Documents'),
              const SizedBox(height: 12),

              // Dashed Box for Banner or Registration Certificate
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE57373), style: BorderStyle.solid, width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDE8E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.document_scanner_outlined, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Club Banner or Registration Certificate (Optional)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Click to upload certificate, brochure, or banner\nPDF, PNG, or JPG (max 5MB)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button: Submit for Verification ▶
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isSubmitting
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B0014),
                          shape: const StadiumBorder(),
                          elevation: 2,
                        ),
                        onPressed: _submit,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Submit for Verification',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
      ),
    );
  }
}
