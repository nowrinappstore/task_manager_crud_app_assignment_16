import 'package:flutter/material.dart';
import 'package:task_manager_crud_app/services/notification_details_screen.dart';

class AppNavigator {
static  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
static void  openDetails(String payload){
  key.currentState?.push(
      MaterialPageRoute(
      builder: (context) =>
          NotificationDetailsScreen(payload: payload) ));

}

}