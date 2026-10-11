import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:task_manager_crud_app/app_navigator.dart';
import 'package:task_manager_crud_app/services/auth_services.dart';
import 'package:task_manager_crud_app/services/notification_lab_screen.dart';
import 'package:task_manager_crud_app/services/notification_service.dart';
import 'package:task_manager_crud_app/services/push_service.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';

class AppStartup {
  static bool firebaseReady = false;
  static String? firebaseError;
}

// Background FCM Handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('Background FCM message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    AppStartup.firebaseReady = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    AppStartup.firebaseError = e.toString();
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize Services
  if (AppStartup.firebaseReady) {
    try {
      // Local notification initialization
      await NotificationService.init();

      // FCM initialization and token setup
      await PushService.init();

      // Show local notification for foreground FCM messages
      NotificationService.listenForegroundMessages();

      // Initialize Google Sign-In
      await GoogleSignIn.instance.initialize();
    } catch (e, stackTrace) {
      debugPrint('Service initialization failed: $e');
      debugPrint('$stackTrace');
    }
  }

  runApp(const MyApp());

  // Handle notification that opened a terminated app
  if (AppStartup.firebaseReady) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushService.handleLaunchMessage();
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.key,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: !AppStartup.firebaseReady
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Firebase initialization failed:\n'
                    '${AppStartup.firebaseError ?? "Unknown error"}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : StreamBuilder<User?>(
              stream: AuthService().authState,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return const Scaffold(
                    body: Center(child: Text('Authentication error occurred.')),
                  );
                }

                if (snapshot.hasData) {
                  return const HomeScreen();
                }

                return const LoginScreen();
              },
            ),
    );
  }
}

// Notification Lab Home Screen
class NotificationLabHomeScreen extends StatelessWidget {
  const NotificationLabHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Lab'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: 'Notification Lab'),
            const SizedBox(height: 16),
            _DemoButton(
              label: '1. Open Notification Lab',
              screen: const NotificationLabScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.label, required this.screen});

  final String label;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
        icon: const Icon(Icons.notifications_active),
        label: Text(label),
      ),
    );
  }
}
