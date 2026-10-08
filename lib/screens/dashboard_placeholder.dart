import 'package:flutter/material.dart';

import '../session_store.dart';
import '../theme.dart';

class DashboardPlaceholder extends StatelessWidget {
  const DashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionStore.current;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retail Billing'),
        actions: [
          TextButton(
            onPressed: () {
              SessionStore.clear();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome${session?.userName.isNotEmpty == true ? ', ${session!.userName}' : ''}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              session?.organizationName ?? 'Your billing workspace is ready.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Phase 1 currently connects Login, Signup, and Forgot Password to the backend APIs. Dashboard and billing pages come next.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
