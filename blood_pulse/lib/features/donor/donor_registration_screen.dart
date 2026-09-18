import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets/custom_app_bar.dart';

class DonorRegistrationScreen extends ConsumerStatefulWidget {
  const DonorRegistrationScreen({super.key});

  @override
  ConsumerState<DonorRegistrationScreen> createState() => _DonorRegistrationScreenState();
}

class _DonorRegistrationScreenState extends ConsumerState<DonorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String? _selectedBloodGroup;
  String? _selectedDistrict;
  String? _selectedUpazila;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  final Map<String, List<String>> _districtToUpazila = {
    'Dhaka': ['Savar', 'Dhamrai', 'Keraniganj', 'Nawabganj'],
    'Chittagong': ['Hathazari', 'Sitakunda', 'Mirsharai', 'Patiya'],
    'Sylhet': ['Sylhet Sadar', 'Biswanath', 'Golapganj'],
    'Rajshahi': ['Paba', 'Godagari', 'Tanore', 'Bagmara'],
  };

  void _register() async {
    if (_formKey.currentState!.validate() && _agreedToTerms) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1)); // Network simulation
      setState(() => _isLoading = false);
      if (mounted) {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Become a Donor',
        showLogo: false,
        showBackButton: true,
        onBack: () => context.go('/login'),
        showNotification: false,
        showProfile: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.padding, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create Account', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Join the national blood donor registry.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: 32),
                
                // Name & Username
                Row(
                  children: [
                    Expanded(child: _buildTextField(controller: _nameController, label: 'Full Name', icon: Icons.person, hint: 'John Doe')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField(controller: _usernameController, label: 'Username', icon: Icons.alternate_email, hint: 'johndoe')),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Password
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock,
                  hint: '••••••••',
                  isPassword: true,
                  helperText: 'Encrypted securely',
                  helperIcon: Icons.shield,
                ),
                const SizedBox(height: 24),

                // Blood Group
                Text('Blood Group', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBloodGroup,
                  items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((bg) => DropdownMenuItem<String>(value: bg, child: Text(bg))).toList(),
                  onChanged: (val) => setState(() => _selectedBloodGroup = val),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.bloodtype, color: AppColors.primaryRed)),
                ),
                const SizedBox(height: 24),

                // District & Upazila
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('District', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDistrict,
                            items: _districtToUpazila.keys.map((d) => DropdownMenuItem<String>(value: d, child: Text(d))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDistrict = val;
                                _selectedUpazila = null; // Reset upazila
                              });
                            },
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.location_city, color: Colors.grey)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upazila', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedUpazila,
                            items: (_selectedDistrict != null ? _districtToUpazila[_selectedDistrict]! : []).map((u) {
                              return DropdownMenuItem<String>(value: u, child: Text(u));
                            }).toList(),
                            onChanged: _selectedDistrict == null ? null : (val) => setState(() => _selectedUpazila = val),
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.map, color: Colors.grey)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Terms
                Row(
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                      activeColor: AppColors.primaryRed,
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            TextSpan(text: 'Terms of Service', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' and '),
                            TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Register Button
                ElevatedButton(
                  onPressed: _isLoading || !_agreedToTerms ? null : _register,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 32),
              ],
            ),
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
    bool isPassword = false,
    String? helperText,
    IconData? helperIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            hintText: hint,
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (helperIcon != null) Icon(helperIcon, size: 12, color: Colors.grey),
              if (helperIcon != null) const SizedBox(width: 4),
              Text(helperText, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ],
    );
  }
}
