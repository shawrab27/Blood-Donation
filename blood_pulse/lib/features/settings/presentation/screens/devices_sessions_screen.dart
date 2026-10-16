// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../services/api_client.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

/// Screen listing active devices and login sessions for the authenticated user.
/// Allows revoking specific devices and logging out of all other sessions.
class DevicesSessionsScreen extends ConsumerStatefulWidget {
  const DevicesSessionsScreen({super.key});

  @override
  ConsumerState<DevicesSessionsScreen> createState() => _DevicesSessionsScreenState();
}

class _DevicesSessionsScreenState extends ConsumerState<DevicesSessionsScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  Future<void> _fetchDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final devices = await _apiClient.getDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _revokeDevice(int deviceId, String deviceName, bool isCurrent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isCurrent ? 'Revoke Current Session?' : 'Revoke Device Session?',
          style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold),
        ),
        content: Text(
          isCurrent
              ? 'Revoking your current device will log you out immediately. Continue?'
              : 'Are you sure you want to revoke session for "$deviceName"? This device will require logging in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _apiClient.revokeDevice(deviceId);
      if (isCurrent) {
        if (mounted) {
          ref.read(authProvider.notifier).logout();
          context.go('/login');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device session revoked successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchDevices();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke device: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _logoutAllOtherDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out All Other Devices?',
          style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will revoke all active login sessions on other phones, tablets, and computers. Your current session will remain active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out Others', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _apiClient.logoutAllDevices(includeCurrent: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All other device sessions have been revoked.'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchDevices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke sessions: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  IconData _getPlatformIcon(String? platform) {
    switch (platform?.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'web':
        return Icons.language_rounded;
      case 'windows':
      case 'macos':
      case 'linux':
        return Icons.laptop_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF24191A)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Text(
          'Devices & Sessions',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0015),
          ),
        ),
      ),
      body: ResponsiveCenterWrapper(
        child: RefreshIndicator(
          onRefresh: _fetchDevices,
          color: AppColors.primary,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: AppLoader(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF24191A)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                onPressed: _fetchDevices,
                child: const Text('Try Again', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final activeDevices = _devices.where((d) => d['is_revoked'] != true).toList();
    final hasOtherActive = activeDevices.any((d) => d['is_current'] != true);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Security Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3DDE0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDEAEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFFC30121), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Security',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF24191A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage all phones and browsers authorized to access your BloodPulse account.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF534343), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (hasOtherActive) ...[
          // Log out all other devices button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC30121),
                side: const BorderSide(color: Color(0xFFC30121), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: _isActionLoading ? null : _logoutAllOtherDevices,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Log Out All Other Devices',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Devices List Header
        Text(
          'Active Sessions (${activeDevices.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF534343),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),

        if (activeDevices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                'No active devices recorded.',
                style: TextStyle(color: Color(0xFF857373)),
              ),
            ),
          )
        else
          ...activeDevices.map((device) => _buildDeviceCard(device)),
      ],
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final int? deviceId = device['id'] as int?;
    final String deviceName = (device['device_name'] as String?) ?? 'Mobile Device';
    final String platform = (device['platform'] as String?) ?? 'unknown';
    final bool isCurrent = device['is_current'] == true;
    final String? ipMasked = device['last_ip_masked'] as String?;
    final String? city = device['last_city_approx'] as String?;
    final String? lastSeen = device['last_seen'] as String?;

    String subtitle = '';
    if (ipMasked != null && ipMasked.isNotEmpty) {
      subtitle += 'IP: $ipMasked';
    }
    if (city != null && city.isNotEmpty) {
      subtitle += (subtitle.isNotEmpty ? ' • ' : '') + city;
    }
    if (lastSeen != null && lastSeen.isNotEmpty) {
      final dateStr = lastSeen.contains('T') ? lastSeen.split('T')[0] : lastSeen;
      subtitle += (subtitle.isNotEmpty ? ' • ' : '') + dateStr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? const Color(0xFFC30121).withValues(alpha: 0.3) : const Color(0xFFF3DDE0),
          width: isCurrent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFFFDEAEB) : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getPlatformIcon(platform),
                color: isCurrent ? const Color(0xFFC30121) : const Color(0xFF4B5563),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          deviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF24191A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF756262)),
                    ),
                  ],
                ],
              ),
            ),
            if (deviceId != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC30121),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                onPressed: _isActionLoading
                    ? null
                    : () => _revokeDevice(deviceId, deviceName, isCurrent),
                child: Text(
                  isCurrent ? 'Log Out' : 'Revoke',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
