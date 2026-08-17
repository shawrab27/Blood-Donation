import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

class SocialFeedScreen extends StatelessWidget {
  const SocialFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Feed'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.padding),
        children: [
          Text('Stories of Impact', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          // Stories Row
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildStoryBubble(context, isNew: true, label: 'Add Story', icon: Icons.add),
                _buildStoryBubble(context, label: 'Rahim'),
                _buildStoryBubble(context, label: 'Sadia'),
                _buildStoryBubble(context, label: 'Karim'),
                _buildStoryBubble(context, label: 'Nadia'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Feed Posts
          _buildFeedPost(
            context,
            author: 'Rahim Uddin',
            time: '2 hours ago',
            content: 'Just donated blood at Dhaka Medical College! Feeling great knowing I could help someone in need. #BloodDonation',
            likes: 42,
            isEmergency: false,
          ),
          const SizedBox(height: 16),
          _buildFeedPost(
            context,
            author: 'Anisur Rahman',
            time: '5 hours ago',
            content: 'URGENT: Need 2 bags of O- blood at Square Hospital immediately. Please share or contact if available.',
            likes: 120,
            isEmergency: true,
          ),
          const SizedBox(height: 16),
          _buildFeedPost(
            context,
            author: 'Sadia Islam',
            time: '1 day ago',
            content: 'Thank you to the generous donor who saved my brother\'s life today. Words cannot express our gratitude.',
            likes: 315,
            isEmergency: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryBubble(BuildContext context, {required String label, bool isNew = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isNew ? AppColors.primaryRed : Colors.grey.shade300, width: 3),
              color: isNew ? AppColors.primaryRed.withValues(alpha: 0.1) : AppColors.secondaryNavy,
            ),
            child: icon != null
                ? Icon(icon, color: AppColors.primaryRed)
                : const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFeedPost(BuildContext context, {required String author, required String time, required String content, required int likes, required bool isEmergency}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.secondaryNavy,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                if (isEmergency)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.critical, borderRadius: BorderRadius.circular(12)),
                    child: const Text('EMERGENCY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(content, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.primaryRed, size: 20),
                const SizedBox(width: 4),
                Text('$likes', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(width: 16),
                const Icon(Icons.comment, color: Colors.grey, size: 20),
                const SizedBox(width: 4),
                Text('Reply', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const Spacer(),
                const Icon(Icons.share, color: Colors.grey, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
