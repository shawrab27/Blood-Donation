import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/pulse_ai_visibility_provider.dart';
import '../../../../core/app_router.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import 'heartbeat_icon.dart';
import '../../../../main.dart'; // To access rootScaffoldMessengerKey if defined there.

class PulseAiOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const PulseAiOverlay({super.key, required this.child});

  @override
  ConsumerState<PulseAiOverlay> createState() => _PulseAiOverlayState();
}

class _PulseAiOverlayState extends ConsumerState<PulseAiOverlay> {
  bool _open = false;
  String _currentRoute = '';
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = ref.read(appRouterProvider);
    _router.routerDelegate.addListener(_onRouteChanged);
    _updateRoute();
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateRoute();
        setState(() {});
      }
    });
  }

  void _updateRoute() {
    try {
      final config = _router.routerDelegate.currentConfiguration;
      String path = '';
      if (config.matches.isNotEmpty) {
        path = config.last.matchedLocation;
      }
      if (path.isEmpty) {
        path = config.uri.path;
      }
      _currentRoute = path;
    } catch (e) {
      _currentRoute = '';
    }
  }

  void _toggle() {
    setState(() {
      _open = !_open;
    });
  }

  void _close() {
    if (_open) {
      setState(() {
        _open = false;
      });
    }
  }

  void _hidePulseAi() async {
    _close();
    await ref.read(pulseAiVisibilityProvider.notifier).setVisible(false);
    if (!mounted) return;
    
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('PulseAI hidden. You can turn it back on from Settings.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isRouteAllowed() {
    if (_currentRoute.isEmpty) return false;
    const hiddenRoutes = [
      '/',
      '/splash',
      '/language',
      '/login',
      '/register',
      '/onboarding',
      '/forgot-password',
      '/verify-otp',
      '/otp-verify',
      '/privacy-policy',
      '/assistant',
    ];
    return !hiddenRoutes.contains(_currentRoute);
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFFC30121),
    Color textColor = const Color(0xFFC30121),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            _close();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(pulseAiVisibilityProvider);
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final routeAllowed = _isRouteAllowed();
    
    final showOverlay = isVisible && isAuthenticated && routeAllowed && !isKeyboardOpen;

    return Stack(
      children: [
        widget.child,
        if (showOverlay) ...[
          if (_open)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
              ),
            ),
          Positioned(
            right: 16,
            bottom: 80 + MediaQuery.paddingOf(context).bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedOpacity(
                  opacity: _open ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedSlide(
                    offset: _open ? Offset.zero : const Offset(0, 0.1),
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_open,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPill(
                            icon: Icons.chat_bubble_outline,
                            label: 'Chat with PulseAI',
                            onTap: () => _router.push('/assistant'),
                          ),
                          _buildPill(
                            icon: Icons.description_outlined,
                            label: 'Analyse blood report',
                            onTap: () => _router.push('/health-hub/ai-report'),
                          ),
                          _buildPill(
                            icon: Icons.person_search_outlined,
                            label: 'Find donors nearby',
                            onTap: () => _router.push('/blood-hub/search'),
                          ),
                          _buildPill(
                            icon: Icons.close,
                            label: 'Hide PulseAI',
                            iconColor: Colors.grey,
                            textColor: Colors.grey,
                            onTap: _hidePulseAi,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggle,
                  child: const HeartbeatIcon(
                    asset: 'assets/images/pulse_ai_icon.png',
                    size: 56,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
