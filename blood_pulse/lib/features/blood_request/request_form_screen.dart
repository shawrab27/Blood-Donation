import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets/custom_app_bar.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  bool _agreedToDSA = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        showLogo: true,
        subtitle: 'Request',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Patient Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Hospital',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Required Units',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.yellow.shade100,
              child: Column(
                children: [
                  const Text(
                    'Digital Security Act 2018 Agreement',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'By submitting this request, I declare that the emergency is genuine. False requests are punishable under the DSA 2018.',
                    textAlign: TextAlign.justify,
                  ),
                  CheckboxListTile(
                    title: const Text('I agree & digitally sign'),
                    value: _agreedToDSA,
                    onChanged: (val) {
                      setState(() {
                        _agreedToDSA = val ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _agreedToDSA ? AppColors.primaryRed : Colors.grey,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _agreedToDSA ? () => context.go('/dashboard') : null,
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }
}
