import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firestore_service.dart';

class NotificationService {
  NotificationService(this._firestore);

  final FirestoreService _firestore;
  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'hydrateai_reminders',
    'Hydration Reminders',
    description: 'Adaptive hydration check-in reminders',
    importance: Importance.high,
  );

  /// Call once after sign-in. [onNotificationTap] should navigate to chat.
  Future<void> init(String uid, {VoidCallback? onNotificationTap}) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (_) => onNotificationTap?.call(),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    final token = await _messaging.getToken();
    if (token != null) await _firestore.saveFcmToken(uid, token);
    _messaging.onTokenRefresh.listen((t) => _firestore.saveFcmToken(uid, t));

    // Foreground: surface as a local notification banner.
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });

    // Background tap → navigate to chat.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (msg.data['screen'] == 'chat') onNotificationTap?.call();
    });
  }
}
