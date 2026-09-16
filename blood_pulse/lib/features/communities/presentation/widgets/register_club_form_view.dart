import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';

class RegisterClubFormView extends ConsumerStatefulWidget {
  const RegisterClubFormView({super.key});

  @override
  ConsumerState<RegisterClubFormView> createState() => _RegisterClubFormViewState();
}

class _RegisterClubFormViewState extends ConsumerState<RegisterClubFormView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _presidentCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _agreedToLifetime = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _presidentCtrl.dispose();
    _contactCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (!_agreedToLifetime) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must agree to the lifetime commitment condition.')),
        );
        return;
      }
      
      // In a real app, send data to backend here.
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Application Submitted', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
          content: const Text('Your application to register a local club has been sent to the Admin for approval.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop(); // Go back
              },
              child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BloodPulseAppBar(
        showBackButton: true,
        subtitle: 'Register Local Club',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apply to Register a Local Club',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill up all basic information to register your local blood donation club on BloodPulse.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.neutral),
              ),
              const SizedBox(height: 24),

              CustomInputField(
                controller: _nameCtrl,
                label: 'Club Name',
                hint: 'Enter the name of the club',
                prefixIcon: Icons.groups_rounded,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              CustomInputField(
                controller: _presidentCtrl,
                label: 'President / Leader Name',
                hint: 'Enter full name',
                prefixIcon: Icons.person_rounded,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              CustomInputField(
                controller: _contactCtrl,
                label: 'Contact Number',
                hint: 'Enter official contact number',
                prefixIcon: Icons.phone_rounded,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              CustomInputField(
                controller: _descCtrl,
                label: 'Club Description',
                hint: 'Tell us about your activities...',
                prefixIcon: Icons.description_rounded,
                maxLines: 4,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Checkbox(
                    value: _agreedToLifetime,
                    onChanged: (val) {
                      setState(() {
                        _agreedToLifetime = val ?? false;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  const Expanded(
                    child: Text(
                      'I agree that this club is committed to lifetime work for humanity and voluntary blood donation.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: CapsuleButton(
                  label: 'Submit Application',
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
