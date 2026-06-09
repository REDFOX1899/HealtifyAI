class StreakModel {
  final int current;
  final int best;
  final String? lastCheckin; // yyyy-MM-dd

  const StreakModel({this.current = 0, this.best = 0, this.lastCheckin});

  factory StreakModel.fromMap(Map<String, dynamic>? data) => StreakModel(
        current: (data?['current'] as num?)?.toInt() ?? 0,
        best: (data?['best'] as num?)?.toInt() ?? 0,
        lastCheckin: data?['last_checkin'] as String?,
      );
}
