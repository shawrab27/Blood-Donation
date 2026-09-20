import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';

enum DispatchRole { requester, donor }

/// Stitch Screen 6 (ID: e73c87ac5dfa4f5dbb643195fef71d5f)
/// Live Dispatch & Step Tracking (Dual Donor-Requester View)
class LiveDispatchScreen extends StatefulWidget {
  const LiveDispatchScreen({
    super.key,
    this.patientName = 'Sarah Jenkins',
    this.hospitalName = 'City General Trauma Wing',
    this.bloodGroup = 'O-',
    this.donorName = 'Tanvir Ahmed',
    this.donorPhone = '+8801711223344',
    this.initialRole = DispatchRole.requester,
  });

  final String patientName;
  final String hospitalName;
  final String bloodGroup;
  final String donorName;
  final String donorPhone;
  final DispatchRole initialRole;

  @override
  State<LiveDispatchScreen> createState() => _LiveDispatchScreenState();
}

class _LiveDispatchScreenState extends State<LiveDispatchScreen>
    with SingleTickerProviderStateMixin {
  late DispatchRole _activeRole;
  int _currentMilestone = 2; // 1: Dispatched, 2: On the Way, 3: Arrived & Prep, 4: Donated
  bool _trafficEnabled = false;

  final MapController _mapController = MapController();

  // GPS Coordinates (Dhaka Route: Dhanmondi to Dhaka Medical / City General)
  final LatLng _originCoord = const LatLng(23.7465, 90.3708); // Dhanmondi 27
  final LatLng _donorCoord = const LatLng(23.7380, 90.3850);  // Mirpur Road transit
  final LatLng _hospitalCoord = const LatLng(23.7259, 90.3976); // City General Trauma Wing

  late AnimationController _radarController;
  late Animation<double> _radarAnimation;

  @override
  void initState() {
    super.initState();
    _activeRole = widget.initialRole;
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _radarAnimation = Tween<double>(begin: 8.0, end: 26.0).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dialer unavailable for $phoneNumber')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open phone dialer: $e')),
      );
    }
  }

  void _openChat({required String name, required String bloodGroup, required String roomId}) {
    context.push(
      '/chat',
      extra: {
        'chatRoomId': roomId,
        'chatRecipientName': name,
        'bloodGroup': bloodGroup,
      },
    );
  }

  void _advanceMilestone() {
    if (_currentMilestone < 4) {
      setState(() => _currentMilestone++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated: ${_getMilestoneTitle(_currentMilestone)}'),
          backgroundColor: const Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getMilestoneTitle(int step) {
    switch (step) {
      case 1:
        return 'Dispatched';
      case 2:
        return 'On the Way (Transit)';
      case 3:
        return 'Arrived & Prep (Ward 04)';
      case 4:
        return 'Donated (Handover Complete)';
      default:
        return '';
    }
  }

  String _getMilestoneDesc(int step) {
    switch (step) {
      case 1:
        return 'Donor accepted request and departed from station.';
      case 2:
        return 'Donor is actively in motion along Mirpur Road to ${widget.hospitalName}.';
      case 3:
        return 'Donor has arrived at ward reception and undergoing vitals check.';
      case 4:
        return 'Blood transfusion completed successfully. Life saved!';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: BloodPulseAppBar(
        showBackButton: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        },
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Navigation breadcrumb
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard');
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back, size: 18, color: Color(0xFF5C3F3D)),
                              SizedBox(width: 6),
                              Text(
                                'Active Requests',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5C3F3D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F1F8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.radar_rounded, size: 13, color: Color(0xFF0D68AA)),
                            SizedBox(width: 4),
                            Text(
                              'LIVE TRACK',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D68AA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 1. Role Switcher / Perspective Toggle
                  _buildRoleSwitcher(),

                  const SizedBox(height: 14),

                  // 2. ETA & Quick Route Card
                  _buildEtaCard(),

                  const SizedBox(height: 14),

                  // 3. 4 Milestone Steps in a Single Horizontal Track
                  _buildMilestoneTrack(),

                  // Donor Action Hub (Visible in Donor View)
                  if (_activeRole == DispatchRole.donor) ...[
                    const SizedBox(height: 12),
                    _buildDonorActionHub(),
                  ],

                  const SizedBox(height: 16),

                  // 4. Embedded 4:3 Interactive Map
                  _buildLiveMapCard(),

                  const SizedBox(height: 14),

                  // 5. Real-Time Sync & Stage Details Card
                  _buildSyncStatusCard(),

                  const SizedBox(height: 14),

                  // 6. Counterparty Card (Donor in Requester View / Patient in Donor View)
                  _buildCounterpartyCard(),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSwitcher() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE9EB),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _activeRole = DispatchRole.requester);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Switched to Requester View (Live Tracking)'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _activeRole == DispatchRole.requester
                      ? const Color(0xFFC30121)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: _activeRole == DispatchRole.requester
                      ? [
                          BoxShadow(
                            color: const Color(0xFFC30121).withAlpha(60),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_pin_circle_rounded,
                      size: 16,
                      color: _activeRole == DispatchRole.requester
                          ? Colors.white
                          : const Color(0xFF5C3F3D),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Requester View',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _activeRole == DispatchRole.requester
                            ? Colors.white
                            : const Color(0xFF5C3F3D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _activeRole = DispatchRole.donor);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Switched to Donor View (Dispatch Control)'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _activeRole == DispatchRole.donor
                      ? const Color(0xFFC30121)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: _activeRole == DispatchRole.donor
                      ? [
                          BoxShadow(
                            color: const Color(0xFFC30121).withAlpha(60),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      size: 16,
                      color: _activeRole == DispatchRole.donor
                          ? Colors.white
                          : const Color(0xFF5C3F3D),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Donor View',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _activeRole == DispatchRole.donor
                            ? Colors.white
                            : const Color(0xFF5C3F3D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtaCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3DDE0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _currentMilestone >= 3 ? 'Arrived' : '18 Mins',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC30121),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE9EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Fast Route',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC30121),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded,
                        size: 15, color: Color(0xFFC30121)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '2.4 km to ${widget.hospitalName}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF5C3F3D),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8E3E5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed_rounded, size: 14, color: Color(0xFF004B7E)),
                    SizedBox(width: 4),
                    Text(
                      '28 km/h',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF1B8A4E)),
                  SizedBox(width: 4),
                  Text(
                    'Clear flow',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Color(0xFF5C3F3D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneTrack() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3DDE0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    'Donation Journey',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24191A),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'SINGLE TRACK',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF004B7E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF004B7E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step $_currentMilestone of 4',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4 Milestone Single Horizontal Line
          Stack(
            alignment: Alignment.center,
            children: [
              // Background track line
              Positioned(
                top: 16,
                left: 30,
                right: 30,
                child: Container(
                  height: 3,
                  color: const Color(0xFFF3DDE0),
                ),
              ),
              // Active fill line
              Positioned(
                top: 16,
                left: 30,
                right: 30,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final fraction = (_currentMilestone - 1) / 3.0;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: constraints.maxWidth * fraction,
                        height: 3,
                        color: const Color(0xFF004B7E),
                      ),
                    );
                  },
                ),
              ),
              // Nodes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMilestoneNode(
                    step: 1,
                    title: 'Dispatched',
                    subtitle: '10:15 AM',
                    icon: Icons.check,
                  ),
                  _buildMilestoneNode(
                    step: 2,
                    title: 'On the Way',
                    subtitle: 'In Transit',
                    icon: Icons.navigation_rounded,
                  ),
                  _buildMilestoneNode(
                    step: 3,
                    title: 'Arrived & Prep',
                    subtitle: 'Ward 04',
                    icon: Icons.medical_services_rounded,
                  ),
                  _buildMilestoneNode(
                    step: 4,
                    title: 'Donated',
                    subtitle: 'Handover',
                    icon: Icons.favorite_rounded,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneNode({
    required int step,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isPassed = step < _currentMilestone;
    final isActive = step == _currentMilestone;

    Color nodeBg;
    Color nodeFg;
    if (isPassed) {
      nodeBg = const Color(0xFF004B7E);
      nodeFg = Colors.white;
    } else if (isActive) {
      nodeBg = const Color(0xFFC30121);
      nodeFg = Colors.white;
    } else {
      nodeBg = const Color(0xFFF3DDE0);
      nodeFg = const Color(0xFF888888);
    }

    return GestureDetector(
      onTap: () => setState(() => _currentMilestone = step),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: nodeBg,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFFC30121).withAlpha(100),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isPassed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : isActive
                      ? const Icon(Icons.radio_button_checked,
                          size: 16, color: Colors.white)
                      : Text(
                          '$step',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: nodeFg,
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: isActive
                  ? const Color(0xFFC30121)
                  : const Color(0xFF24191A),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 8,
              color: Color(0xFF004B7E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorActionHub() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE9EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3DDE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFFC30121)),
                  SizedBox(width: 6),
                  Text(
                    'Donor Action Hub',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24191A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('GPS broadcast refreshed to 23.7380° N, 90.3850° E'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1E4FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location_rounded, size: 12, color: Color(0xFF004B7E)),
                      SizedBox(width: 4),
                      Text(
                        'Refresh GPS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF004B7E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _advanceMilestone,
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: Text(
                    _currentMilestone == 2
                        ? 'Mark Arrived at Ward'
                        : _currentMilestone == 3
                            ? 'Mark Donated'
                            : 'Completed',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC30121),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _makeCall('+8801700000000'),
                  icon: const Icon(Icons.emergency_rounded, size: 14, color: Color(0xFFC30121)),
                  label: const Text(
                    'Hospital Liaison',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24191A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE6BDBA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMapCard() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3DDE0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _donorCoord,
                initialZoom: 14.2,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.bloodpulse.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_originCoord, _donorCoord, _hospitalCoord],
                      strokeWidth: 5,
                      color: const Color(0xFFC30121),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Origin Marker (Donor station)
                    Marker(
                      point: _originCoord,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF5F5E5E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.home_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                    // Moving Donor Beacon
                    Marker(
                      point: _donorCoord,
                      width: 50,
                      height: 50,
                      child: AnimatedBuilder(
                        animation: _radarAnimation,
                        builder: (ctx, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: _radarAnimation.value * 1.8,
                                height: _radarAnimation.value * 1.8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFC30121).withAlpha(
                                      (255 * (1 - _radarController.value) * 0.4).toInt()),
                                ),
                              ),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC30121),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.two_wheeler_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // Destination Hospital Pin
                    Marker(
                      point: _hospitalCoord,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF960017),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Floating Top Badges
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(235),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF004B7E)),
                        SizedBox(width: 5),
                        Text(
                          'Geo-Shield Guard',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24191A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() => _trafficEnabled = !_trafficEnabled);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_trafficEnabled ? 'Traffic layer enabled' : 'Traffic layer hidden'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(235),
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Icon(
                        Icons.traffic_rounded,
                        size: 16,
                        color: _trafficEnabled ? const Color(0xFFC30121) : const Color(0xFF5F5E5E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Floating Bottom Controls Map Badges
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(240),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mirpur Road, Dhaka',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24191A),
                          ),
                        ),
                        Text(
                          'Passing Dhanmondi 27',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            color: Color(0xFF5C3F3D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FloatingActionButton.small(
                    heroTag: 'recenter_map',
                    onPressed: () {
                      _mapController.move(_donorCoord, 14.5);
                    },
                    backgroundColor: const Color(0xFFC30121),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    child: const Icon(Icons.my_location_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3DDE0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync_rounded, size: 15, color: Color(0xFF004B7E)),
                  SizedBox(width: 6),
                  Text(
                    'Synced via BloodPulse Mesh • Live',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C3F3D),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 2.5, backgroundColor: Color(0xFF1B8A4E)),
                    SizedBox(width: 4),
                    Text(
                      '100% Encrypted',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B8A4E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFF3DDE0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step $_currentMilestone: ${_getMilestoneTitle(_currentMilestone)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getMilestoneDesc(_currentMilestone),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF5C3F3D),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '10:24 AM (Active)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC30121),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterpartyCard() {
    final isRequester = _activeRole == DispatchRole.requester;
    final name = isRequester ? widget.donorName : widget.patientName;
    final phone = isRequester ? widget.donorPhone : '+8801700000000';
    final roleTag = isRequester ? 'Universal Donor' : 'Patient / Ward 04';
    final subtitle = isRequester
        ? '★ 4.9 • 14 Lifesaving Units'
        : '${widget.hospitalName} • Urgent';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3DDE0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFFEE9EB),
                        child: Text(
                          name.isNotEmpty ? name[0] : 'T',
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC30121),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFF004B7E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF24191A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF5C3F3D),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC30121),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      widget.bloodGroup,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roleTag,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC30121),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _makeCall(phone),
                  icon: const Icon(Icons.call, size: 15),
                  label: Text(
                    isRequester ? 'Call Donor' : 'Call Ward Desk',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC30121),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openChat(
                    name: name,
                    bloodGroup: widget.bloodGroup,
                    roomId: isRequester ? 'donor_tanvir_o_minus' : 'ward_sarah_o_minus',
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: const Text(
                    'Send Message',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE9EB),
                    foregroundColor: const Color(0xFFC30121),
                    side: const BorderSide(color: Color(0xFFF3DDE0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
