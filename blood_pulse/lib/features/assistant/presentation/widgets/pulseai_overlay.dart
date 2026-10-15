import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/pulse_ai_visibility_provider.dart';
import '../../../../core/app_router.dart';
import '../../../../main.dart'; // To access rootScaffoldMessengerKey if defined there.

class PulseAiOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const PulseAiOverlay({super.key, required this.child});

  @override
  ConsumerState<PulseAiOverlay> createState() => _PulseAiOverlayState();
}

class _PulseAiOverlayState extends ConsumerState<PulseAiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scrimOpacity;
  late final Animation<double> _iconMorph;
  String _currentRoute = '';
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _scrimOpacity = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _iconMorph = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _router = ref.read(appRouterProvider);
    _router.routerDelegate.addListener(_onRouteChanged);
    _updateRoute();
  }

  @override
  void dispose() {
    _animController.dispose();
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

  bool _open = false;

  void _toggle() {
    setState(() {
      _open = !_open;
    });
    if (_open) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  void _close() {
    if (_open) {
      setState(() {
        _open = false;
      });
      _animController.reverse();
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
    if (_currentRoute.isEmpty) return true; // Default to true in tests/unmatched shells
    const hiddenRoutes = [
      '/',
      '/splash',
      '/language',
      '/login',
      '/register',
      '/onboarding',
      '/forgot-password',
      '/verify-otp',
      '/privacy-policy',
      '/assistant',
    ];
    return !hiddenRoutes.any((r) => _currentRoute == r || _currentRoute.startsWith('$r/'));
  }

  bool _hasBottomNav() {
    const shellTabRoutes = [
      '/feed',
      '/blood-hub',
      '/communities',
      '/health-hub',
      '/profile',
      '/dashboard',
    ];
    return shellTabRoutes.contains(_currentRoute);
  }

  Widget _buildStaggeredPill({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFFC30121),
    Color textColor = const Color(0xFF2B2B2B),
    Color backgroundColor = Colors.white,
    Border? border,
  }) {
    // 4 pills with staggered intervals: index 0 is nearest to FAB (bottom-most)
    final double startInterval = (index * 0.12).clamp(0.0, 0.6);
    final double endInterval = (startInterval + 0.40).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        if (!_open && _animController.value == 0.0) {
          return const SizedBox.shrink();
        }
        final val = animation.value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: val,
          alignment: Alignment.centerRight,
          child: Opacity(
            opacity: val,
            child: child,
          ),
        );
      },
      child: Container(
        height: 44,
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 32).clamp(180.0, 320.0),
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(50),
          border: border ?? Border.all(color: const Color(0xFFF0DCDC), width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () {
              _close();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(pulseAiVisibilityProvider);
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final routeAllowed = _isRouteAllowed();

    final showOverlay = isVisible && routeAllowed && !isKeyboardOpen;

    return PopScope(
      canPop: _animController.value == 0.0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _animController.value > 0.0) {
          _close();
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (showOverlay) ...[
            // Fading Scrim
            AnimatedBuilder(
              animation: _scrimOpacity,
              builder: (context, child) {
                if (_scrimOpacity.value == 0.0) return const SizedBox.shrink();
                return Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35 * _scrimOpacity.value),
                    ),
                  ),
                );
              },
            ),
            // Floating Action Speed-Dial Container
            Positioned(
              right: 16,
              bottom: (_hasBottomNav() ? 80.0 : 20.0) + MediaQuery.paddingOf(context).bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Staggered Pills expanding upward
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Topmost (pill 3)
                      _buildStaggeredPill(
                        index: 3,
                        icon: Icons.visibility_off_outlined,
                        label: 'Hide PulseAI',
                        iconColor: const Color(0xFF888888),
                        textColor: const Color(0xFF666666),
                        backgroundColor: const Color(0xFFF9F9F9),
                        onTap: _hidePulseAi,
                      ),
                      // Pill 2
                      _buildStaggeredPill(
                        index: 2,
                        icon: Icons.person_search_outlined,
                        label: 'Find donors nearby',
                        onTap: () => _router.push('/blood-hub/search'),
                      ),
                      // Pill 1
                      _buildStaggeredPill(
                        index: 1,
                        icon: Icons.description_outlined,
                        label: 'Analyse blood report',
                        onTap: () => _router.push('/health-hub/ai-report'),
                      ),
                      // Pill 0 (nearest to FAB)
                      _buildStaggeredPill(
                        index: 0,
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chat with PulseAI',
                        iconColor: const Color(0xFFC30121),
                        textColor: const Color(0xFFC30121),
                        border: Border.all(color: const Color(0xFFC30121), width: 1.2),
                        onTap: () => _router.push('/assistant'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // FAB that morphs between Stitch PulseAI Icon and Close 'X'
                  GestureDetector(
                    key: const Key('pulseai_fab_button'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggle,
                    child: AnimatedBuilder(
                      animation: _iconMorph,
                      builder: (context, _) {
                        final morphVal = _iconMorph.value;
                        return SizedBox(
                          width: 58,
                          height: 58,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // PulseAI Minimalist Blood Drop with Pulse Icon (from Stitch screen 429fd13037924bbe9fcdd6aef8a61fb5)
                              if (morphVal < 0.95)
                                Transform.scale(
                                  scale: (1.0 - morphVal).clamp(0.0, 1.0),
                                  child: Opacity(
                                    opacity: (1.0 - morphVal).clamp(0.0, 1.0),
                                    child: Image.asset(
                                      'assets/images/pulseai_icon.png',
                                      width: 58,
                                      height: 58,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              // Close 'X' Icon (rotates and scales up when expanded)
                              if (morphVal > 0.05)
                                Transform.rotate(
                                  angle: (1.0 - morphVal) * 1.5,
                                  child: Transform.scale(
                                    scale: morphVal.clamp(0.0, 1.0),
                                    child: Opacity(
                                      opacity: morphVal.clamp(0.0, 1.0),
                                      child: Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          border: Border.all(
                                            color: const Color(0xFFF0DCDC),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFC30121).withValues(alpha: 0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: Color(0xFFC30121),
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
