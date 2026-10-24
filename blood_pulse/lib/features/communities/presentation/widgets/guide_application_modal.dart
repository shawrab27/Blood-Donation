import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/location_cascade_selector.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../services/api_client.dart';
import '../../../profile/domain/providers/profile_provider.dart';

// USER RULE - do not change: Phase F Guide Application Modal with 4 S1 PrimaryButton states
class GuideApplicationModal extends ConsumerStatefulWidget {
  final String? overrideStatus;
  final String? overrideButtonState;
  final bool? overrideCanApply;
  final String? overrideReapplyDate;
  final Future<bool> Function(Map<String, dynamic> data)? onSubmit;

  const GuideApplicationModal({
    super.key,
    this.overrideStatus,
    this.overrideButtonState,
    this.overrideCanApply,
    this.overrideReapplyDate,
    this.onSubmit,
  });

  @override
  ConsumerState<GuideApplicationModal> createState() => _GuideApplicationModalState();
}

class _GuideApplicationModalState extends ConsumerState<GuideApplicationModal> {
  final _formKey = GlobalKey<FormState>();
  final _introController = TextEditingController();
  final _proofController = TextEditingController();

  String? _division;
  String? _district;
  String? _upazila;
  bool _allowCalls = true;

  bool _isLoading = false;
  bool _isFetchingStatus = false;
  String _status = 'none';
  String _buttonState = 'Apply Now';
  bool _canApply = true;
  String? _reapplyDate;
  String? _rejectionReason;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.overrideButtonState != null) {
      _buttonState = widget.overrideButtonState!;
      _status = widget.overrideStatus ?? 'none';
      _canApply = widget.overrideCanApply ?? (_buttonState == 'Apply Now');
      _reapplyDate = widget.overrideReapplyDate;
    } else {
      _fetchApplicationStatus();
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _proofController.dispose();
    super.dispose();
  }

  Future<void> _fetchApplicationStatus() async {
    setState(() => _isFetchingStatus = true);
    try {
      final response = await ApiClient().get('communities/guide-application/');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _status = data['status'] as String? ?? 'none';
            _buttonState = data['button_state'] as String? ?? 'Apply Now';
            _canApply = data['can_apply'] as bool? ?? true;
            _reapplyDate = data['reapply_date'] as String?;
            _rejectionReason = data['rejection_reason'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('[GuideApplicationModal] Status fetch error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingStatus = false);
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_district == null || _district!.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select your District.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final payload = {
      'intro': _introController.text.trim(),
      'allow_calls': _allowCalls,
      'division': _division,
      'district': _district,
      'upazila': _upazila,
      'area_name': _upazila != null ? '$_upazila, $_district' : (_district ?? ''),
      'proof_photo': _proofController.text.trim(),
    };

    try {
      if (widget.onSubmit != null) {
        final success = await widget.onSubmit!(payload);
        if (success && mounted) {
          setState(() {
            _status = 'pending';
            _buttonState = 'Pending review';
            _canApply = false;
          });
        }
        return;
      }

      final res = await ApiClient().post('communities/guide-application/', body: payload);
      if (res.statusCode == 201 || res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _status = 'pending';
            _buttonState = 'Pending review';
            _canApply = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your Guide application has been submitted for review!'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        final msg = err['error'] ?? 'Failed to submit application. Please try again.';
        if (mounted) setState(() => _errorMessage = msg.toString());
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final initialDistrict = _district ?? profile?.district;
    final initialUpazila = _upazila ?? profile?.upazila;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Become a Local Guide',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.secondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Help coordinate emergency blood donations in your local community.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.neutral,
                ),
              ),
              const SizedBox(height: 16),

              if (_isFetchingStatus)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              else ...[
                if (_status == 'gated')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEEBA)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF856404), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please complete your profile (name, phone number, and district) before applying.',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF856404)),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF3D2D5)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.primary),
                    ),
                  ),

                if (_status == 'rejected' && _rejectionReason != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCCD2)),
                    ),
                    child: Text(
                      _reapplyDate != null
                          ? 'Previous application note: $_rejectionReason (Eligible to re-apply on $_reapplyDate)'
                          : 'Previous application note: $_rejectionReason',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.primary),
                    ),
                  ),

                // Area Selection
                const Text(
                  'Your Service Area',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                LocationCascadeSelector(
                  initialDistrict: initialDistrict,
                  initialUpazila: initialUpazila,
                  enabled: _canApply && _status != 'gated',
                  onChanged: (div, dist, upa) {
                    setState(() {
                      _division = div;
                      _district = dist;
                      _upazila = upa;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Introduction Field
                const Text(
                  'Introduction (Max 200 characters)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _introController,
                  enabled: _canApply && _status != 'gated',
                  maxLength: 200,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Briefly describe your experience and availability for community coordination...',
                    hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (!_canApply) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Please provide a short introduction.';
                    }
                    if (value.trim().length > 200) {
                      return 'Maximum 200 characters allowed.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Allow Calls Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9ECEF)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: const Text(
                      'Allow Direct Phone Calls',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    subtitle: const Text(
                      'Seekers and donors in emergency need can reach you directly.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral),
                    ),
                    value: _allowCalls,
                    onChanged: (_canApply && _status != 'gated')
                        ? (val) => setState(() => _allowCalls = val)
                        : null,
                  ),
                ),
                ),
                const SizedBox(height: 16),

                // Optional Proof Photo
                const Text(
                  'Verification Proof Photo (Optional)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _proofController,
                  enabled: _canApply && _status != 'gated',
                  decoration: InputDecoration(
                    hintText: 'Link or ID document reference (optional)',
                    hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.link_rounded, color: Colors.grey, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // S1 PrimaryButton enforcing the 4 states
                PrimaryButton(
                  label: _buttonState,
                  isLoading: _isLoading,
                  backgroundColor: _canApply && _status != 'gated' ? AppColors.primary : Colors.grey.shade400,
                  onPressed: (_canApply && _status != 'gated' && !_isLoading)
                      ? _submitApplication
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
