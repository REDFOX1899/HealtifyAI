import 'package:cloud_firestore/cloud_firestore.dart';

class HydrationLog {
  final String id;
  final double oz;
  final DateTime timestamp;
  final String source; // 'manual' | 'photo' | 'chat'
  final double? aiConfidence;

  const HydrationLog({
    required this.id,
    required this.oz,
    required this.timestamp,
    this.source = 'manual',
    this.aiConfidence,
  });

  factory HydrationLog.fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return HydrationLog(
      id: doc.id,
      oz: (data['oz'] as num?)?.toDouble() ?? 0,
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] as String? ?? 'manual',
      aiConfidence: (data['ai_confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'oz': oz,
        'timestamp': Timestamp.fromDate(timestamp),
        'source': source,
        if (aiConfidence != null) 'ai_confidence': aiConfidence,
      };
}
