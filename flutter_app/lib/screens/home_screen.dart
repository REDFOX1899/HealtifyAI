import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/hydration_log.dart';
import '../models/streak_model.dart';
import '../models/user_model.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets/hydration_ring.dart';
import '../widgets/streak_badge.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsScreen(uid: uid)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatScreen(uid: uid)),
        ),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Check In'),
      ),
      body: StreamBuilder<UserModel>(
        stream: firestore.watchUser(uid),
        builder: (context, userSnap) {
          final user = userSnap.data ??
              UserModel(uid: uid, name: 'friend');
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}, ${user.name} 👋',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.offwhite,
                  ),
                ),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: TextStyle(
                      color: AppColors.offwhite.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      HydrationRing(
                        ozConsumed: user.ozToday,
                        dailyGoal: user.dailyGoalOz,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(user.progress * 100).round()}% of your daily goal',
                        style: const TextStyle(
                            color: AppColors.teal, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                StreamBuilder<StreakModel>(
                  stream: firestore.watchStreak(uid),
                  builder: (context, snap) {
                    final streak = snap.data ?? const StreakModel();
                    return Center(
                      child: StreakBadge(
                          current: streak.current, best: streak.best),
                    );
                  },
                ),
                const SizedBox(height: 32),
                const Text(
                  'Recent activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.offwhite,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<HydrationLog>>(
                  stream: firestore.watchRecentLogs(uid),
                  builder: (context, snap) {
                    final logs = snap.data ?? const <HydrationLog>[];
                    if (logs.isEmpty) {
                      return Text(
                        'No check-ins yet today. Tap Check In to start!',
                        style: TextStyle(
                            color: AppColors.offwhite.withValues(alpha: 0.5)),
                      );
                    }
                    return Column(
                      children: [for (final log in logs) _ActivityTile(log)],
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile(this.log);

  final HydrationLog log;

  @override
  Widget build(BuildContext context) {
    final icon = switch (log.source) {
      'photo' => Icons.camera_alt,
      'chat' => Icons.chat_bubble_outline,
      _ => Icons.water_drop,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.teal),
      title: Text(
        '${log.oz.round()} oz',
        style: const TextStyle(color: AppColors.offwhite),
      ),
      trailing: Text(
        DateFormat('h:mm a').format(log.timestamp),
        style: TextStyle(color: AppColors.offwhite.withValues(alpha: 0.5)),
      ),
    );
  }
}
