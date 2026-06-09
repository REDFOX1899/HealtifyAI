import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrateai/providers.dart';
import 'package:hydrateai/screens/chat_screen.dart';
import 'package:hydrateai/services/api_service.dart';
import 'package:hydrateai/services/firestore_service.dart';

const uid = 'test-user';

/// Fake API that mimics the checkIn Cloud Function: it writes the AI
/// reply to Firestore just like the real backend does.
class FakeApiService implements ApiService {
  FakeApiService(this.db);

  final FakeFirebaseFirestore db;
  int checkInCalls = 0;

  @override
  Future<CheckInResult> checkIn({
    required String userId,
    required String message,
    String? photoUrl,
  }) async {
    checkInCalls++;
    await db.collection('users').doc(userId).collection('messages').add({
      'text': 'Nice work, Sam! Keep that streak going. 💧',
      'sender': 'ai',
      'timestamp': DateTime.now(),
    });
    return const CheckInResult(coachReply: 'Nice work!', ozLogged: 8, streak: 3);
  }

  @override
  Future<Map<String, dynamic>> verifyPhoto({
    required String userId,
    required String photoUrl,
  }) async =>
      {'oz_consumed': 8, 'confidence': 0.9};
}

Widget buildChat(FakeFirebaseFirestore db, FakeApiService api,
    {required bool premium}) {
  return ProviderScope(
    overrides: [
      firestoreServiceProvider
          .overrideWithValue(FirestoreService(db: db)),
      apiServiceProvider.overrideWithValue(api),
      isPremiumProvider.overrideWith((ref) async => premium),
    ],
    child: const MaterialApp(home: ChatScreen(uid: uid)),
  );
}

void main() {
  late FakeFirebaseFirestore db;
  late FakeApiService api;

  setUp(() {
    db = FakeFirebaseFirestore();
    api = FakeApiService(db);
  });

  testWidgets('sending a message writes to Firestore', (tester) async {
    await tester.pumpWidget(buildChat(db, api, premium: false));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('chat_input')), 'drank 8 oz of water');
    await tester.tap(find.byKey(const Key('send_button')));
    await tester.pumpAndSettle();

    final messages =
        await db.collection('users').doc(uid).collection('messages').get();
    final userMsgs =
        messages.docs.where((d) => d.data()['sender'] == 'user').toList();
    expect(userMsgs, hasLength(1));
    expect(userMsgs.first.data()['text'], 'drank 8 oz of water');
    expect(api.checkInCalls, 1);
  });

  testWidgets('AI response appears in the chat list', (tester) async {
    await tester.pumpWidget(buildChat(db, api, premium: false));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chat_input')), 'hello coach');
    await tester.tap(find.byKey(const Key('send_button')));
    await tester.pumpAndSettle();

    expect(
        find.text('Nice work, Sam! Keep that streak going. 💧'), findsOneWidget);
  });

  testWidgets('camera button is hidden for free-tier users', (tester) async {
    await tester.pumpWidget(buildChat(db, api, premium: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('camera_button')), findsNothing);
  });

  testWidgets('camera button is visible for premium users', (tester) async {
    await tester.pumpWidget(buildChat(db, api, premium: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('camera_button')), findsOneWidget);
  });
}
