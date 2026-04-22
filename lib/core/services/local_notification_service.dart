import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? rootNavigatorKey;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    rootNavigatorKey = navigatorKey;
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == 'saved_reports') {
          rootNavigatorKey?.currentContext?.goNamed('saved_reports');
        }
      },
    );
  }

  Future<void> showNotification({required int id, required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'intent_general', 'General Notifications',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id: id, 
      title: title, 
      body: body, 
      notificationDetails: platformChannelSpecifics
    );
  }

  Future<void> showReportGeneratedNotification(String filePath) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'intent_reports', 'AI Reports',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id: 0, 
      title: 'Analytics Report Ready', 
      body: 'Your AI insights PDF has been generated and saved.', 
      notificationDetails: platformChannelSpecifics,
      payload: 'saved_reports',
    );
  }
}
