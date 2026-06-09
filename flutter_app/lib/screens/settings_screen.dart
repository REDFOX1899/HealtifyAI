import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import 'paywall_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Premium section
          isPremium.when(
            data: (premium) => premium
                ? const ListTile(
                    leading: Icon(Icons.star, color: AppColors.gold),
                    title: Text('Premium active',
                        style: TextStyle(color: AppColors.offwhite)),
                    subtitle: Text('Thanks for supporting HydrateAI!'),
                  )
                : Card(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    child: ListTile(
                      leading: const Icon(Icons.star_border,
                          color: AppColors.gold),
                      title: const Text('Upgrade to Premium',
                          style: TextStyle(color: AppColors.offwhite)),
                      subtitle: const Text(
                          'AI photo verification, smart reminders & more'),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.teal),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaywallScreen()),
                      ),
                    ),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(height: 32),
          // Smart reminders are a premium feature.
          isPremium.when(
            data: (premium) => SwitchListTile(
              title: const Text('Smart adaptive reminders',
                  style: TextStyle(color: AppColors.offwhite)),
              subtitle: Text(premium
                  ? 'AI shifts reminder times to match your habits'
                  : 'Premium feature — upgrade to enable'),
              value: premium,
              activeColor: AppColors.teal,
              onChanged: premium
                  ? (v) {/* TODO: persist preference */}
                  : (_) => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PaywallScreen()),
                      ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.teal),
            title: const Text('Sign out',
                style: TextStyle(color: AppColors.offwhite)),
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}
