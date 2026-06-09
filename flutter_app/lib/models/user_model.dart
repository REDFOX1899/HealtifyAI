class UserModel {
  final String uid;
  final String name;
  final int dailyGoalOz;
  final double ozToday;
  final bool adhdMode;
  final String? fcmToken;

  const UserModel({
    required this.uid,
    required this.name,
    this.dailyGoalOz = 64,
    this.ozToday = 0,
    this.adhdMode = false,
    this.fcmToken,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) => UserModel(
        uid: uid,
        name: data['name'] as String? ?? 'friend',
        dailyGoalOz: (data['daily_goal'] as num?)?.toInt() ?? 64,
        ozToday: (data['oz_today'] as num?)?.toDouble() ?? 0,
        adhdMode: data['adhd_mode'] as bool? ?? false,
        fcmToken: data['fcm_token'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'daily_goal': dailyGoalOz,
        'oz_today': ozToday,
        'adhd_mode': adhdMode,
        if (fcmToken != null) 'fcm_token': fcmToken,
      };

  double get progress =>
      dailyGoalOz == 0 ? 0 : (ozToday / dailyGoalOz).clamp(0.0, 1.0);
}
