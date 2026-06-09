import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers.dart';
import '../theme.dart';

/// First-run setup: name, daily goal, ADHD mode toggle.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.uid, this.onDone});

  final String uid;
  final VoidCallback? onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  double _goalOz = 64;
  bool _adhdMode = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await ref.read(firestoreServiceProvider).saveUserProfile(
          UserModel(
            uid: widget.uid,
            name: _nameController.text.trim().isEmpty
                ? 'friend'
                : _nameController.text.trim(),
            dailyGoalOz: _goalOz.round(),
            adhdMode: _adhdMode,
          ),
        );
    if (mounted) widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                "Let's set you up 💧",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.offwhite,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.offwhite),
                decoration: const InputDecoration(
                  labelText: 'What should your coach call you?',
                  labelStyle: TextStyle(color: AppColors.teal),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.teal),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Daily goal: ${_goalOz.round()} oz',
                style: const TextStyle(
                    fontSize: 18, color: AppColors.offwhite),
              ),
              Slider(
                value: _goalOz,
                min: 32,
                max: 128,
                divisions: 12,
                activeColor: AppColors.teal,
                onChanged: (v) => setState(() => _goalOz = v),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('ADHD mode',
                    style: TextStyle(color: AppColors.offwhite)),
                subtitle: Text(
                  'Adaptive reminders that learn your rhythm instead of '
                  'nagging on a fixed schedule.',
                  style: TextStyle(
                      color: AppColors.offwhite.withValues(alpha: 0.6)),
                ),
                value: _adhdMode,
                activeColor: AppColors.teal,
                onChanged: (v) => setState(() => _adhdMode = v),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _saving ? null : _finish,
                  child: Text(_saving ? 'Saving...' : "Let's go"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
