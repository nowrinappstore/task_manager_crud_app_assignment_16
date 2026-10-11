
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
static final FlutterLocalNotificationsPlugin _plugin =
FlutterLocalNotificationsPlugin();

static bool _initialized = false;
static bool _foregroundListenerInitialized = false;

static const NotificationDetails _details = NotificationDetails(
android: AndroidNotificationDetails(
'Class_channel',
'Class Notifications',
channelDescription: 'Notifications from Task Manager',
importance: Importance.max,
priority: Priority.high,
),
iOS: DarwinNotificationDetails(),
);

// Initialize Local Notifications
static Future<void> init() async {
if (_initialized) return;

tz.initializeTimeZones();
tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

const InitializationSettings settings = InitializationSettings(
android: AndroidInitializationSettings('@mipmap/ic_launcher'),
iOS: DarwinInitializationSettings(),
);

await _plugin.initialize(
settings: settings,
onDidReceiveNotificationResponse: onTap,
onDidReceiveBackgroundNotificationResponse: onTap,
);

final android = _plugin
    .resolvePlatformSpecificImplementation<
AndroidFlutterLocalNotificationsPlugin>();

await android?.requestNotificationsPermission();
await android?.requestExactAlarmsPermission();

_initialized = true;
debugPrint('Local notifications initialized.');
}

// Handle Local Notification Tap
@pragma('vm:entry-point')
static void onTap(NotificationResponse response) {
final payload = response.payload;
debugPrint('Local notification tapped. Payload: $payload');

// এখানে payload ব্যবহার করে নির্দিষ্ট Task Details Screen খুলতে পারবেন।
// Screen navigation-এর জন্য আপনার AppNavigator ব্যবহার করা যাবে।
}

// Initialize Firebase Cloud Messaging
static Future<void> initializeFCM() async {
final messaging = FirebaseMessaging.instance;

final settings = await messaging.requestPermission(
alert: true,
badge: true,
sound: true,
provisional: false,
);

debugPrint(
'FCM permission: ${settings.authorizationStatus}',
);

final token = await getFCMToken();

debugPrint('========== FCM TOKEN ==========');
debugPrint(token ?? 'FCM token unavailable');
debugPrint('===============================');

messaging.onTokenRefresh.listen((newToken) {
debugPrint('FCM token refreshed: $newToken');
});
}

// Get FCM Token
static Future<String?> getFCMToken() async {
try {
return await FirebaseMessaging.instance.getToken();
} catch (e) {
debugPrint('Unable to get FCM token: $e');
return null;
}
}

// Listen for Foreground FCM Messages
static void listenForegroundMessages() {
if (_foregroundListenerInitialized) return;
_foregroundListenerInitialized = true;

FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
final String title = message.notification?.title ??
message.data['title']?.toString() ??
'New Task';

final String body = message.notification?.body ??
message.data['body']?.toString() ??
'You have a new task';

final String? taskId = message.data['taskId']?.toString();

await showNotification(
id: message.messageId?.hashCode ?? message.hashCode,
title: title,
body: body,
payload: taskId,
);

debugPrint('Foreground notification displayed: $title');
});
}

// Show Immediate Local Notification
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

// Schedule Notification Internally
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
debugPrint('Exact alarm failed; trying inexact mode: $e');
await run(AndroidScheduleMode.inexactAllowWhileIdle);
}
}

// Schedule Task Reminder
static Future<void> scheduleTaskNotification({
required int id,
required String title,
required DateTime scheduledDate,
}) async {
final scheduledTime = tz.TZDateTime.from(
scheduledDate,
tz.local,
);

if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
debugPrint('Task due date has already passed.');
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

// Schedule Notification After a Delay
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

debugPrint(
'Notification scheduled in ${delay.inSeconds}s. ID: $id',
);
}

// Convert Task ID into a Notification ID
static int notificationIdFor(String taskId) {
int hash = 0;

for (final unit in taskId.codeUnits) {
hash = (hash * 31 + unit) & 0x7FFFFFFF;
}

// Keep notification ID positive and non-zero.
return hash == 0 ? 1 : hash;
}

// Cancel Task Reminder
static Future<void> cancelTaskNotification({
required int id,
}) async {
await _plugin.cancel(id: id);
debugPrint('Task notification cancelled: $id');
}

// Cancel All Notifications
static Future<void> cancelAll() async {
await _plugin.cancelAll();
debugPrint('All notifications cancelled.');
}
}

