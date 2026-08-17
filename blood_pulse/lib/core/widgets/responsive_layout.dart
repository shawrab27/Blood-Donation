import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A wrapper widget that ensures a consistent, responsive layout across all platforms.
///
/// On wider viewports (Web, Desktop, Tablets), it constrains the content's
/// maximum width and centers it with an elegant subtle container look.
/// On narrower viewports (Mobile), it behaves as a full-screen layout.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth = 500.0,
    this.padding = const EdgeInsets.all(16.0),
    this.backgroundColor = AppColors.surface,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool isLargeScreen = screenWidth > maxWidth;

        return Scaffold(
          backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Container(
              width: isLargeScreen ? maxWidth : double.infinity,
              height: double.infinity,
              padding: padding,
              decoration: isLargeScreen
                  ? BoxDecoration(
                      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12), // ~0.05 opacity
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.symmetric(
                        vertical: BorderSide(
                          color: Colors.grey.withAlpha(38), // ~0.15 opacity
                          width: 1,
                        ),
                      ),
                    )
                  : null,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
