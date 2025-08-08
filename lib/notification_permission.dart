import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as dev;

Future<void> requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    dev.log('✅ User granted notification permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    dev.log('User granted provisional permission');
  } else {
    dev.log('❌ User declined or has not accepted permission');
  }
}