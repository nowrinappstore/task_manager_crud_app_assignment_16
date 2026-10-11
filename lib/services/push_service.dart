import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:task_manager_crud_app/app_navigator.dart';

class PushService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final ValueNotifier<List<RemoteMessage>> foreGroundMessage =
      ValueNotifier<List<RemoteMessage>>([]);

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // FCM Token
    await getToken();

    // Token refresh
    _messaging.onTokenRefresh.listen((String token) {
      debugPrint('FCM Token refreshed: $token');
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.messageId}, ${message.data}');

      foreGroundMessage.value = [...foreGroundMessage.value, message];
    });

    // App opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
  }

  // App opened from terminated state
  static Future<void> handleLaunchMessage() async {
    final RemoteMessage? message = await _messaging.getInitialMessage();

    if (message != null) {
      _openFromMessage(message);
    }
  }

  static void _openFromMessage(RemoteMessage remote) {
    final taskId = remote.data['taskId']?.toString();

    if (taskId != null && taskId.isNotEmpty) {
      AppNavigator.openDetails(taskId);
    } else {
      AppNavigator.openDetails('No Task ID provided');
    }
  }

  static Future<String?> getToken() async {
    try {
      final String? token = await _messaging.getToken();

      debugPrint('FCM Token: $token');

      return token;
    } catch (e) {
      debugPrint('Unable to get FCM Token: $e');
      return null;
    }
  }
}
