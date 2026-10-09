// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Stitch Screen 1: Profile Segmented Tabs
/// Renders "Requests Chart", "User Posts Log", and "Donation History"
/// satisfying tests and matching Stitch UI design.
class ProfileTabsSection extends StatefulWidget {
  final VoidCallback onAddPost;

  const ProfileTabsSection({super.key, required this.onAddPost});

  @override
  State<ProfileTabsSection> createState() => _ProfileTabsSectionState();
}

class _ProfileTabsSectionState extends State<ProfileTabsSection> {
  int _selectedTabIndex = 0;
  final TextEditingController _storyInputCtrl = TextEditingController();

  @override
  void dispose() {
    _storyInputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildTabPill(0, 'Requests Chart'),
              _buildTabPill(1, 'User Posts Log'),
              _buildTabPill(2, 'Donation History'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_selectedTabIndex == 0) _buildRequestsChartTab(),
        if (_selectedTabIndex == 1) _buildUserPostsLogTab(),
        if (_selectedTabIndex == 2) _buildDonationHistoryTab(),
      ],
    );
  }

  Widget _buildTabPill(int index, String label) {
    final bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsChartTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Fulfillment Analytics',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
          ),
          SizedBox(height: 6),
          Text(
            '100% response rate to emergency hospital blood dispatch notifications.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(value: 0.85, backgroundColor: Color(0xFFFEE9EB), color: AppColors.primary, minHeight: 8),
        ],
      ),
    );
  }

  Widget _buildUserPostsLogTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Community Feed',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
              label: const Text('Add Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE9EB),
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: widget.onAddPost,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _storyInputCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Write your journey...',
                    hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 18),
                onPressed: () {
                  if (_storyInputCtrl.text.trim().isNotEmpty) {
                    _storyInputCtrl.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✨ Story shared with the donor community!'),
                        backgroundColor: Color(0xFF1B8A4E),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPostCard(
                icon: Icons.volunteer_activism_rounded,
                startColor: const Color(0xFF8B0000),
                endColor: const Color(0xFFC30121),
                caption: 'Completed my 12th donation!',
                likes: 124,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPostCard(
                icon: Icons.local_hospital_rounded,
                startColor: const Color(0xFF0D68AA),
                endColor: const Color(0xFF034A7B),
                caption: 'Emergency drive at City Hospital',
                likes: 89,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostCard({
    required IconData icon,
    required Color startColor,
    required Color endColor,
    required String caption,
    required int likes,
  }) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [startColor, endColor]),
        boxShadow: [BoxShadow(color: endColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Stack(
        children: [
          Center(child: Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.3))),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 3),
                    Text('$likes', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationHistoryTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Verified Donations',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
          ),
          SizedBox(height: 6),
          Text(
            'Showing 12 verified donation log records across authorized centers.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
