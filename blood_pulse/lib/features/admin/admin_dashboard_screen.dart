import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/blood_pulse_app_bar.dart';
import '../../services/api_client.dart';
import '../auth/presentation/providers/auth_notifier.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  List<dynamic> _requests = [];
  List<dynamic> _flags = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // 30s silent auto-poll for admin requests and flags without blocking spinners
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _silentPollData();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentPollData() async {
    try {
      final reqRes = await _apiClient.get('requests/');
      if (reqRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(reqRes.body);
        _requests = data.where((r) => r['is_active'] == true).toList();
      }

      final flagRes = await _apiClient.get('flags/');
      if (flagRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(flagRes.body);
        _flags = data.where((f) => f['resolved'] == false).toList();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final reqRes = await _apiClient.get('requests/');
      if (reqRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(reqRes.body);
        _requests = data.where((r) => r['is_active'] == true).toList();
      }

      final flagRes = await _apiClient.get('flags/');
      if (flagRes.statusCode == 200) {
        final List<dynamic> data = jsonDecode(flagRes.body);
        _flags = data.where((f) => f['resolved'] == false).toList();
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markRequestFulfilled(dynamic id) async {
    setState(() => _isLoading = true);
    try {
      // 1. Send PATCH to /api/requests/{id}/ with is_active: false & status: approved
      final patchRes = await _apiClient.patch('requests/$id/', body: {
        'is_active': false,
        'status': 'approved',
      });

      if (patchRes.statusCode >= 200 && patchRes.statusCode < 300) {
        // 2. Automatically record action in POST /api/admin-actions/
        try {
          await _apiClient.post('admin-actions/', body: {
            'action_type': 'REQUEST_FULFILLED',
            'target_id': id,
            'notes': 'Approved via Admin Dashboard',
          });
        } catch (e) {
          debugPrint('Error logging admin action audit: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request #$id fulfilled and logged successfully.', style: const TextStyle(fontFamily: 'Inter')),
              backgroundColor: AppColors.tertiary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
          );
        }
        await _loadData();
      } else {
        throw Exception('Server returned [${patchRes.statusCode}]: ${patchRes.body}');
      }
    } catch (e) {
      debugPrint('Error marking request fulfilled: $e');
      if (mounted) {
        _showErrorDialog('Fulfill Request Failed', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resolveFlag(dynamic id) async {
    setState(() => _isLoading = true);
    try {
      // 1. Send PATCH to /api/flags/{id}/ with resolved: true
      final patchRes = await _apiClient.patch('flags/$id/', body: {
        'resolved': true,
      });

      if (patchRes.statusCode >= 200 && patchRes.statusCode < 300) {
        // 2. Automatically record action in POST /api/admin-actions/
        try {
          await _apiClient.post('admin-actions/', body: {
            'action_type': 'FLAG_RESOLVED',
            'target_id': id,
          });
        } catch (e) {
          debugPrint('Error logging admin action audit: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Flag #$id resolved successfully.', style: const TextStyle(fontFamily: 'Inter')),
              backgroundColor: AppColors.tertiary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
          );
        }
        await _loadData();
      } else {
        throw Exception('Server returned [${patchRes.statusCode}]: ${patchRes.body}');
      }
    } catch (e) {
      debugPrint('Error resolving flag: $e');
      if (mounted) {
        _showErrorDialog('Resolve Flag Failed', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Georgia', color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Inter', color: AppColors.secondary),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bool isAdmin = authState.isAuthenticated;

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const BloodPulseAppBar(
          subtitle: 'Admin Dashboard',
          showBackButton: true,
        ),
        body: const Center(
          child: Text(
            'Access Denied. Admins only.',
            style: TextStyle(fontFamily: 'Inter', color: AppColors.secondary, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BloodPulseAppBar(
        subtitle: 'Admin Dashboard',
        showBackButton: true,
      ),
      body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: _isLoading && _requests.isEmpty && _flags.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // Pending Requests Header
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Pending Requests',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          '${_requests.length}',
                          style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (_requests.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No active requests.', style: TextStyle(fontFamily: 'Inter', color: AppColors.secondary)),
                      ),
                    ..._requests.map((r) => Card(
                          color: Colors.white,
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            title: Text(
                              '${r['blood_group']} needed at ${r['hospital_location']}',
                              style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w600, color: AppColors.secondary),
                            ),
                            subtitle: Text(
                              'Patient: ${r['patient_name']}',
                              style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF5F5E5E)),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.tertiary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onPressed: () => _markRequestFulfilled(r['id']),
                              child: const Text('Fulfill Request', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                            ),
                          ),
                        )),
                    const Divider(height: 32, color: Color(0xFFEAE0E0)),
                    // Flagged Accounts Header
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Flagged Accounts',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.tertiary,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          '${_flags.length}',
                          style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (_flags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No unresolved flags.', style: TextStyle(fontFamily: 'Inter', color: AppColors.secondary)),
                      ),
                    ..._flags.map((f) => Card(
                          color: Colors.white,
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            title: Text(
                              'Reason: ${f['reason'] ?? 'Unknown'}',
                              style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w600, color: AppColors.secondary),
                            ),
                            subtitle: Text(
                              'Donor Username: ${f['donor_username'] ?? 'Unknown'}',
                              style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF5F5E5E)),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onPressed: () => _resolveFlag(f['id']),
                              child: const Text('Resolve Flag', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                            ),
                          ),
                        )),
                  ],
                ),
        ),
    );
  }
}
