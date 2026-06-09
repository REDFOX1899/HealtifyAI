import 'package:flutter/material.dart';

import '../theme.dart';

class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.current, required this.best});

  final int current;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            '🔥 $current-day streak',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your best: $best days',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.offwhite.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
