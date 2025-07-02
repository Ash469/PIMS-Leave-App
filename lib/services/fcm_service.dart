import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart'; // <-- Add for navigation if needed
import 'dart:io'; // <-- For platform checks

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print('🔔 Local notification tapped: ${response.payload}');
        }
        // TODO: Handle notification tap if needed
      },
    );

    // Request permissions on iOS and Android 13+
    if (Platform.isIOS) {
      await _messaging.requestPermission();
    } else if (Platform.isAndroid) {
      // Android 13+ requires runtime notification permission
      final androidInfo = await _messaging.getNotificationSettings();
      if (androidInfo.authorizationStatus != AuthorizationStatus.authorized) {
        await _messaging.requestPermission();
      }
    }

    // Get the token (optional, for debugging)
    final token = await _messaging.getToken();
    if (kDebugMode) {
      print('🔔 FCM Token: $token');
    }

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print('🔔 FCM Foreground message received: ${message.notification?.title} - ${message.notification?.body}');
      }
      // Show local notification
      if (message.notification != null) {
        await _localNotifications.show(
          message.notification.hashCode,
          message.notification?.title ?? '',
          message.notification?.body ?? '',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fcm_default_channel', // channel id
              'Notifications', // channel name
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: message.data.toString(),
        );
      }
    });

    // Listen for background messages (when app is opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('🔔 FCM onMessageOpenedApp: ${message.notification?.title} - ${message.notification?.body}');
      }
      // TODO: Handle navigation if needed
    });

    // Optionally handle background messages (requires a top-level handler)
    // See Firebase docs for setup if needed

    // The warning "Unable to log event: analytics library is missing" is safe to ignore.
    // It does not affect notification delivery. No code changes are required.
  }
}
