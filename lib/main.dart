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

// --- ADDED THIS SECTION FOR FOREGROUND NOTIFICATIONS ---
/// Create a [AndroidNotificationChannel] for heads up notifications
late AndroidNotificationChannel channel;

/// Initialize the [FlutterLocalNotificationsPlugin] package.
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  dev.log('Handling a background message ${message.messageId}');
}

// --- ADDED for notification tap handling ---
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  dev.log('Notification tapped in background: ${notificationResponse.payload}');
}
// --- END OF SECTION ---


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- ADDED THIS SECTION TO HANDLE FOREGROUND NOTIFICATIONS ---
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

    // --- UPDATED iOS permission and notification tap handling ---
    // The problematic onDidReceiveLocalNotification parameter is removed.
    const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
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
        // You can add navigation logic here based on the payload.
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    // --- END of update ---


    /// Create an Android Notification Channel.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /// Update the iOS foreground notification presentation options to allow
    /// heads up notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
  // --- END OF SECTION ---

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
          // It's safer to handle potential type mismatches.
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
            // Handle QR code scanned data here if needed
          },
          tab: 'departure', // Default to departure tab
        ),
      },
    );
  }
}

// New RootScreen widget to handle initial navigation
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();
    // --- ADDED THIS LISTENER FOR FOREGROUND MESSAGES ---
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
            // --- ADDED iOS NOTIFICATION DETAILS ---
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
    // --- END OF LISTENER ---

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
      // Add more fields if needed

      if (kDebugMode) {
        dev.log('🔑 Checking login state: isLoggedIn=$isLoggedIn, role=$role, token=$token, name=$name, email=$email');
      }

      // Use a shorter delay during tests
      final isTestEnvironment = const bool.fromEnvironment('flutter.test');
      await Future.delayed(isTestEnvironment ? const Duration(milliseconds: 100) : const Duration(milliseconds: 500)); 

      // Check for all required fields
      final hasAllFields = isLoggedIn && role != null && token != null && name != null && email != null;

      if (hasAllFields) {
        // --- UPDATED THIS BLOCK TO GET AND STORE FCM TOKEN ---
        if (kDebugMode) {
            try {
                final fcmToken = await FirebaseMessaging.instance.getToken();
                if (fcmToken != null) {
                    dev.log('📱 FCM Token for testing: $fcmToken');
                    // Store the latest token in SharedPreferences
                    await prefs.setString('fcm_token', fcmToken);
                    dev.log('✅ FCM Token saved to SharedPreferences.');
                } else {
                    dev.log('📱 Could not retrieve FCM Token.');
                }
            } catch (e) {
                dev.log('⚠️ Error getting FCM token: $e');
            }
        }
        // --- END OF BLOCK ---

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
        // Clear any partial/invalid login state
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
    // Simple splash/loading UI while checking login state
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
