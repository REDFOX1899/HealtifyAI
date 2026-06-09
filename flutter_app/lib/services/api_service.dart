import 'package:cloud_functions/cloud_functions.dart';

class CheckInResult {
  final String coachReply;
  final double ozLogged;
  final int streak;

  const CheckInResult({
    required this.coachReply,
    required this.ozLogged,
    required this.streak,
  });
}

class ApiService {
  ApiService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Calls the `checkIn` Cloud Function (which runs the LangGraph agent).
  Future<CheckInResult> checkIn({
    required String userId,
    required String message,
    String? photoUrl,
  }) async {
    final result = await _functions.httpsCallable('checkIn').call({
      'user_id': userId,
      'message': message,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return CheckInResult(
      coachReply: data['coach_reply'] as String? ?? '',
      ozLogged: (data['oz_logged'] as num?)?.toDouble() ?? 0,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>> verifyPhoto({
    required String userId,
    required String photoUrl,
  }) async {
    final result = await _functions.httpsCallable('verifyPhoto').call({
      'user_id': userId,
      'photo_url': photoUrl,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}
