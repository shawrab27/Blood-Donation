import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/widgets/custom_app_bar.dart';

class DonorMapScreen extends StatelessWidget {
  const DonorMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        showLogo: true,
        showBackButton: true,
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.grey.shade200,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.white)),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: 150,
            child: Column(
              children: [
                const Icon(Icons.location_on, color: AppColors.primaryRed, size: 48),
                Container(
                  padding: const EdgeInsets.all(4),
                  color: Colors.white,
                  child: const Text('A+ Donor', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
