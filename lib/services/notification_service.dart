import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  // ============================================================
  // Local Notification Plugin
  // ============================================================

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  // ============================================================
  // Notification Details
  // ============================================================

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'Class_channel',
      'Class Notifications',
      channelDescription: 'Notification from our app',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  // ============================================================
  // INITIALIZE LOCAL NOTIFICATION
  // ============================================================

  static Future<void> init() async {
    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: onTap,
      onDidReceiveBackgroundNotificationResponse: onTap,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
    >();

    // Android 13+ notification permission
    await android?.requestNotificationsPermission();

    // Android 12+ exact alarm permission
    await android?.requestExactAlarmsPermission();
  }

  // ============================================================
  // NOTIFICATION TAP
  // ============================================================

  @pragma('vm:entry-point')
  static void onTap(NotificationResponse response) {
    final payload = response.payload;

    debugPrint('Notification tapped: $payload');
  }

  // ============================================================
  // FCM INITIALIZE
  // ============================================================

  static Future<void> initializeFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Get FCM Token
    final token = await messaging.getToken();

    debugPrint('================================');
    debugPrint('FCM TOKEN');
    debugPrint('$token');
    debugPrint('================================');

    // Token refresh
    messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
    });

    // FOREGROUND MESSAGE
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('================================');
      debugPrint('FOREGROUND FCM MESSAGE');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');
      debugPrint('================================');

      final notification = message.notification;

      if (notification != null) {
        await showNotification(
          id: message.hashCode,
          title: notification.title ?? 'New Task',
          body: notification.body ?? 'You have a new notification',
          payload: message.data['taskId'],
        );
      }
    });

    // BACKGROUND NOTIFICATION TAP
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened from background');
      debugPrint('Task ID: ${message.data['taskId']}');
    });

    // TERMINATED STATE
    final initialMessage = await messaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('Notification opened from terminated state');
      debugPrint('Task ID: ${initialMessage.data['taskId']}');
    }
  }

  // ============================================================
  // SHOW LOCAL NOTIFICATION
  // ============================================================

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  // ============================================================
  // INTERNAL: SCHEDULE WITH FALLBACK
  // Exact alarm permission না থাকলে নিজে থেকে inexact এ নামবে
  // ============================================================

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    String? payload,
  }) async {
    Future<void> run(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: mode,
        payload: payload,
      );
    }

    try {
      await run(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      debugPrint('Exact alarm not allowed, using inexact: $e');
      await run(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  // ============================================================
  // SCHEDULE TASK NOTIFICATION
  // ============================================================

  static Future<void> scheduleTaskNotification({
    required int id,
    required String title,
    required DateTime scheduledDate,
  }) async {
    final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

    // Past date হলে schedule করবে না
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint('Notification date is already passed.');
      return;
    }

    await _schedule(
      id: id,
      title: title,
      body: 'Your task is due now.',
      when: scheduledTime,
      payload: id.toString(),
    );

    debugPrint('Task notification scheduled: $id');
  }

  // ============================================================
  // SCHEDULE AFTER A DELAY (testing / lab)
  // ============================================================

  static Future<void> scheduleIn({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    String? payload,
  }) async {
    final scheduledTime = tz.TZDateTime.now(tz.local).add(delay);

    await _schedule(
      id: id,
      title: title,
      body: body,
      when: scheduledTime,
      payload: payload,
    );

    debugPrint('Notification scheduled in ${delay.inSeconds}s (id: $id)');
  }

  // ============================================================
  // TASK ID -> NOTIFICATION ID
  // Firestore এর String id থেকে stable positive int বানায়
  // ============================================================

  static int notificationIdFor(String taskId) {
    int hash = 0;
    for (final unit in taskId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return hash;
  }

  // ============================================================
  // CANCEL
  // ============================================================

  static Future<void> cancelTaskNotification({required int id}) async {
    await _plugin.cancel(id: id);
    debugPrint('Task notification cancelled: $id');
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('All notifications cancelled');
  }
}