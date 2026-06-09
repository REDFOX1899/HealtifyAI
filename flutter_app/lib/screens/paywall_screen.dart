import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../providers.dart';
import '../theme.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;

  Future<void> _purchase() async {
    setState(() => _busy = true);
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      if (package == null) throw Exception('No offering configured');
      await Purchases.purchasePackage(package);
      ref.invalidate(isPremiumProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase was not completed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    await Purchases.restorePurchases();
    ref.invalidate(isPremiumProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(
                    child: _PlanCard(
                      title: 'FREE',
                      price: '\$0 / month',
                      features: [
                        'Manual logging',
                        'Basic reminders',
                        'Streak tracking',
                      ],
                      highlighted: false,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _PlanCard(
                      title: 'PREMIUM',
                      price: '\$4.99 / month',
                      features: [
                        'AI photo verification',
                        'AI coach',
                        'Smart reminders',
                        'Advanced analytics',
                      ],
                      highlighted: true,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _busy ? null : _purchase,
                child: Text(_busy ? 'Processing...' : 'Upgrade to Premium'),
              ),
            ),
            TextButton(
              onPressed: _restore,
              child: const Text('Restore purchases',
                  style: TextStyle(color: AppColors.teal)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.highlighted,
  });

  final String title;
  final String price;
  final List<String> features;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.teal.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? AppColors.teal
              : Colors.white.withValues(alpha: 0.1),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: highlighted ? AppColors.teal : AppColors.offwhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(price,
              style: const TextStyle(color: AppColors.gold, fontSize: 15)),
          const SizedBox(height: 16),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 16, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(f,
                        style: const TextStyle(
                            color: AppColors.offwhite, fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
