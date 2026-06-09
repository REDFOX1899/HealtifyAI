import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final authStateProvider = StreamProvider(
    (ref) => ref.watch(authServiceProvider).authStateChanges);

/// RevenueCat premium entitlement check.
final isPremiumProvider = FutureProvider<bool>(
    (ref) => ref.watch(authServiceProvider).isPremium());

/// True while waiting for an AI coach reply in the chat.
final chatLoadingProvider = StateProvider<bool>((ref) => false);
final chatErrorProvider = StateProvider<String?>((ref) => null);
