import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'theme.dart';

// Pass at build time: flutter run --dart-define=REVENUECAT_KEY=goog_xxx
const _revenueCatKey = String.fromEnvironment('REVENUECAT_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  if (_revenueCatKey.isNotEmpty) {
    await Purchases.configure(PurchasesConfiguration(_revenueCatKey));
  } else {
    debugPrint('RevenueCat key missing — premium features disabled.');
  }
  runApp(const ProviderScope(child: HydrateAIApp()));
}

class HydrateAIApp extends ConsumerWidget {
  const HydrateAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'HydrateAI',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: authState.when(
        data: (user) =>
            user == null ? const _SignInScreen() : _AuthedRoot(user: user),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
    );
  }
}

/// Decides between onboarding and home, and boots notifications.
class _AuthedRoot extends ConsumerStatefulWidget {
  const _AuthedRoot({required this.user});

  final User user;

  @override
  ConsumerState<_AuthedRoot> createState() => _AuthedRootState();
}

class _AuthedRootState extends ConsumerState<_AuthedRoot> {
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    NotificationService(ref.read(firestoreServiceProvider))
        .init(widget.user.uid);
    ref
        .read(firestoreServiceProvider)
        .watchUser(widget.user.uid)
        .first
        .then((u) {
      if (mounted && u.name != 'friend') setState(() => _onboarded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_onboarded) {
      return OnboardingScreen(
        uid: widget.user.uid,
        onDone: () => setState(() => _onboarded = true),
      );
    }
    return HomeScreen(uid: widget.user.uid);
  }
}

class _SignInScreen extends ConsumerStatefulWidget {
  const _SignInScreen();

  @override
  ConsumerState<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<_SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💧', style: TextStyle(fontSize: 64)),
              const Text(
                'HydrateAI',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppColors.offwhite,
                ),
              ),
              Text(
                'Your AI hydration accountability coach',
                style:
                    TextStyle(color: AppColors.offwhite.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _email,
                style: const TextStyle(color: AppColors.offwhite),
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                style: const TextStyle(color: AppColors.offwhite),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                onPressed: () => _run(() =>
                    auth.signInWithEmail(_email.text.trim(), _password.text)),
                child: const Text('Sign in'),
              ),
              TextButton(
                onPressed: () => _run(() =>
                    auth.signUpWithEmail(_email.text.trim(), _password.text)),
                child: const Text('Create account',
                    style: TextStyle(color: AppColors.teal)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.login, color: AppColors.teal),
                label: const Text('Continue with Google',
                    style: TextStyle(color: AppColors.offwhite)),
                onPressed: () => _run(() async {
                  await auth.signInWithGoogle();
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
