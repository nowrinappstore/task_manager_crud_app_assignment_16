import 'package:flutter/material.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static void openDetails(String taskId) {
    final navigator = key.currentState;

    if (navigator == null) {
      debugPrint('Navigator is not ready.');
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailsScreen(taskId: taskId),
      ),
    );
  }
}

class NotificationDetailsScreen extends StatelessWidget {
  const NotificationDetailsScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Details')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_active,
                size: 60,
                color: Colors.indigo,
              ),
              const SizedBox(height: 16),
              const Text(
                'Task Notification',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Task ID: $taskId', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
