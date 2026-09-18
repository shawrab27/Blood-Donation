import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets/custom_app_bar.dart';
import 'presentation/providers/blood_request_provider.dart';

class BloodRequestScreen extends ConsumerStatefulWidget {
  const BloodRequestScreen({super.key});

  @override
  ConsumerState<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends ConsumerState<BloodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _contactController = TextEditingController();
  
  String? _selectedBloodGroup;
  String _urgencyLevel = 'Emergency'; // Critical, Emergency, Scheduled
  bool _dsaAgreed = false;
  bool _isLoading = false;

  void _submitRequest() async {
    if (_formKey.currentState!.validate() && _dsaAgreed) {
      if (_selectedBloodGroup == null) return;
      setState(() => _isLoading = true);

      final success = await ref.read(bloodRequestProvider.notifier).createRequest(
            patientName: _patientNameController.text.trim(),
            bloodGroup: _selectedBloodGroup!,
            urgencyLevel: _urgencyLevel,
            hospitalLocation: _hospitalController.text.trim(),
            contactNumber: _contactController.text.trim(),
          );

      setState(() => _isLoading = false);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency request broadcasted!'), backgroundColor: AppColors.success),
        );
        context.go('/dashboard');
      } else {
        final err = ref.read(bloodRequestProvider).errorMessage ?? 'Failed to submit request.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.critical),
        );
      }
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'Critical': return AppColors.critical;
      case 'Emergency': return AppColors.warning;
      case 'Scheduled': return AppColors.success;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showLogo: true,
        subtitle: 'Emergency',
        showBackButton: true,
        onBack: () => context.go('/dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.padding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Request Blood',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Broadcast an emergency request to all active donors in your vicinity.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Urgency Badge Selector
              Text('Urgency Level', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: ['Critical', 'Emergency', 'Scheduled'].map((urgency) {
                  final isSelected = _urgencyLevel == urgency;
                  final color = _getUrgencyColor(urgency);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: InkWell(
                        onTap: () => setState(() => _urgencyLevel = urgency),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? color : Theme.of(context).cardTheme.color,
                            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              urgency,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Patient Name
              _buildTextField(controller: _patientNameController, label: 'Patient Name', icon: Icons.person, hint: 'Full Name'),
              const SizedBox(height: 16),
              
              // Blood Group & Units
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blood Group', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBloodGroup,
                          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                          onChanged: (val) => setState(() => _selectedBloodGroup = val),
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.bloodtype, color: AppColors.primaryRed)),
                          validator: (val) => val == null ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(controller: TextEditingController(text: '1'), label: 'Units Needed', icon: Icons.local_hospital, hint: '1', keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 16),

              // Hospital & Contact
              _buildTextField(controller: _hospitalController, label: 'Hospital Location', icon: Icons.local_hospital, hint: 'Name of hospital'),
              const SizedBox(height: 16),
              _buildTextField(controller: _contactController, label: 'Contact Number', icon: Icons.phone, hint: 'Phone number', keyboardType: TextInputType.phone),
              const SizedBox(height: 32),

              // DSA Compliance
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.warning),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _dsaAgreed,
                      onChanged: (val) => setState(() => _dsaAgreed = val ?? false),
                      activeColor: AppColors.warning,
                    ),
                    Expanded(
                      child: Text(
                        'I legally verify this is a real medical emergency. False requests are punishable under the Digital Security Act.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading || !_dsaAgreed ? null : _submitRequest,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign, size: 20),
                          SizedBox(width: 8),
                          Text('Broadcast Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            hintText: hint,
          ),
        ),
      ],
    );
  }
}
