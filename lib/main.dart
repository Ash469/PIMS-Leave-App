import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/role_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/warden_dashboard_screen.dart';
import 'screens/leave_request_screen.dart';
import 'screens/parent_profile_screen.dart';
import 'screens/guard_dashboard_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'models/data_models.dart';
import 'firebase_options.dart';
import 'dart:developer' as dev;

/// Create a [AndroidNotificationChannel] for heads up notifications
late AndroidNotificationChannel channel;

/// Initialize the [FlutterLocalNotificationsPlugin] package.
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  dev.log('Handling a background message ${message.messageId}');
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  dev.log('Notification tapped in background: ${notificationResponse.payload}');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (!kIsWeb) {
    channel = const AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.high,
    );

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


    // The problematic onDidReceiveLocalNotification parameter is removed.
    const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
      android: AndroidInitializationSettings('launch_background'),
    );
    // The new handlers for notification taps are added here.
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        final String? payload = notificationResponse.payload;
        if (notificationResponse.payload != null) {
          dev.log('FOREGROUND notification payload: $payload');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );


    /// Create an Android Notification Channel.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /// heads up notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ease Exit', // Updated App Title
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const RootScreen(), // <-- Use RootScreen to handle navigation logic
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          
          final role = settings.arguments;
          if (role is UserRole) {
             return MaterialPageRoute(
              builder: (context) => LoginScreen(role: role),
            );
          }
        }
        
        return null;
      },
      routes: {
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/student-dashboard': (context) => const StudentDashboardScreen(),
        '/parent-dashboard': (context) => const ParentDashboardScreen(),
        '/warden-dashboard': (context) => const WardenDashboardScreen(),
        '/guard-dashboard': (context) => const GuardDashboardScreen(), // new route
        '/request-leave': (context) => const LeaveRequestScreen(),
        '/parent-profile': (context) => const ParentProfileScreen(),
        '/qr-scanner': (context) => QrScannerScreen(
          onQrCodeScanned: (qrData) {
          },
          tab: 'departure', // Default to departure tab
        ),
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null && !kIsWeb) { // Simplified check
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: 'launch_background',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
         dev.log('Foreground notification displayed: ${notification.title}');
      }
    });


    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final role = prefs.getString('role');
      final token = prefs.getString('token');
      final name = prefs.getString('name');
      final email = prefs.getString('email');

      if (kDebugMode) {
        dev.log('🔑 Checking login state: isLoggedIn=$isLoggedIn, role=$role, token=$token, name=$name, email=$email');
      }

      final isTestEnvironment = const bool.fromEnvironment('flutter.test');
      await Future.delayed(isTestEnvironment ? const Duration(milliseconds: 100) : const Duration(milliseconds: 500)); 

      final hasAllFields = isLoggedIn && role != null && token != null && name != null && email != null;

      if (hasAllFields) {
        if (kDebugMode) {
            try {
                final fcmToken = await FirebaseMessaging.instance.getToken();
                if (fcmToken != null) {
                    dev.log('📱 FCM Token for testing: $fcmToken');
                    await prefs.setString('fcm_token', fcmToken);
                    dev.log('✅ FCM Token saved to SharedPreferences.');
                } else {
                    dev.log('📱 Could not retrieve FCM Token.');
                }
            } catch (e) {
                dev.log('⚠️ Error getting FCM token: $e');
            }
        }

        if (mounted) {
          if (role == 'student') {
            Navigator.of(context).pushReplacementNamed('/student-dashboard');
          } else if (role == 'parent') {
            Navigator.of(context).pushReplacementNamed('/parent-dashboard');
          } else if (role == 'warden') {
            Navigator.of(context).pushReplacementNamed('/warden-dashboard');
          } else if (role == 'guard') {
            Navigator.of(context).pushReplacementNamed('/guard-dashboard');
          } else {
            Navigator.of(context).pushReplacementNamed('/role-selection');
          }
        }
      } else {
        await prefs.clear(); // Use clear() for a more robust logout
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/role-selection');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        dev.log('⚠️ Error loading SharedPreferences: $e');
      }
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/role-selection');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
