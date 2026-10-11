import 'package:flutter/material.dart';
class NotificationDetailsScreen extends StatelessWidget {
  const NotificationDetailsScreen({super.key,required this.payload});
  final String payload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Details'),
      ),
      body: Center(
        child: Text(payload),
      ),
    );
  }
}
