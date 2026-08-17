import 'package:flutter/material.dart';
import '../../../../views/profile/profile_screen.dart';

/// Delegate widget rendering the full interactive ProfileScreen inside the 5-Tab Persistent Navigation Shell.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}
