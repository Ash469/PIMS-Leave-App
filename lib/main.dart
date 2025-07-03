import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
    // Initialize FCM Service
  try {
    final fcmService = FCMService();
    await fcmService.initialize();
    if (kDebugMode) {
      print('🔔 FCM Service initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Error initializing FCM Service: $e');
    }
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PIMS',
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
          final UserRole role = settings.arguments as UserRole;
          return MaterialPageRoute(
            builder: (context) => LoginScreen(role: role),
          );
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
        print('🔑 Checking login state: isLoggedIn=$isLoggedIn, role=$role, token=$token, name=$name, email=$email');
      }

      await Future.delayed(const Duration(milliseconds: 500)); 

      // Check for all required fields
      final hasAllFields = isLoggedIn && role != null && token != null && name != null && email != null;

      if (mounted) {
        if (hasAllFields) {
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
        } else {
          // Clear any partial/invalid login state
          await prefs.remove('isLoggedIn');
          await prefs.remove('role');
          await prefs.remove('token');
          await prefs.remove('name');
          await prefs.remove('email');
          Navigator.of(context).pushReplacementNamed('/role-selection');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading SharedPreferences: $e');
      }
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/role-selection');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple splash/loading UI while checking login state
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
           
          
          ],
        ),
      ),
    );
  }
}

