import 'package:flutter/material.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  /// Called by PushService when a notification is tapped.
  /// Replace [_PushDetailsScreen] with your real details screen if you have one.
  static void openDetails(String screen) {
    key.currentState?.push(
      MaterialPageRoute(
        builder: (_) => _PushDetailsScreen(screen: screen),
      ),
    );
  }
}

class _PushDetailsScreen extends StatelessWidget {
  const _PushDetailsScreen({required this.screen});

  final String screen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Details')),
      body: Center(
        child: Text('Opened from notification: $screen'),
      ),
    );
  }
}
