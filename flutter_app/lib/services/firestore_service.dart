import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/hydration_log.dart';
import '../models/streak_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  Stream<UserModel> watchUser(String uid) => _userRef(uid)
      .snapshots()
      .map((snap) => UserModel.fromMap(uid, snap.data() ?? {}));

  Stream<StreakModel> watchStreak(String uid) => _userRef(uid)
      .collection('stats')
      .doc('streak')
      .snapshots()
      .map((snap) => StreakModel.fromMap(snap.data()));

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String uid) =>
      _userRef(uid)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots();

  Stream<List<HydrationLog>> watchRecentLogs(String uid, {int limit = 3}) =>
      _userRef(uid)
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(HydrationLog.fromDoc).toList());

  Future<void> sendUserMessage(String uid, String text, {String? photoUrl}) =>
      _userRef(uid).collection('messages').add({
        'text': text,
        'sender': 'user',
        'timestamp': FieldValue.serverTimestamp(),
        if (photoUrl != null) 'photo_url': photoUrl,
      });

  Future<void> addLog(String uid, HydrationLog log) async {
    await _userRef(uid).collection('logs').add(log.toMap());
    await _userRef(uid)
        .set({'oz_today': FieldValue.increment(log.oz)}, SetOptions(merge: true));
  }

  Future<void> saveUserProfile(UserModel user) =>
      _userRef(user.uid).set(user.toMap(), SetOptions(merge: true));

  Future<void> saveFcmToken(String uid, String token) =>
      _userRef(uid).set({'fcm_token': token}, SetOptions(merge: true));
}
