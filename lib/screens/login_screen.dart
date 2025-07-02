import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  final dynamic role;
  const LoginScreen({super.key, this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  User? user;
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  late SharedPreferences prefs;
  String role = '';
  String? _authErrorMessage; // <-- Add this line

  late AnimationController _animationController;
  late Animation<double> _animation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadRoleFromPrefs();

    // Animation for moving background
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: false);
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  Future<void> _loadRoleFromPrefs() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? '';
    });
    print('Loaded role from prefs: $role');
  }

  Future<void> signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _authErrorMessage = null;
    });
    try {
      // Start Google sign-in flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get authentication details from the signed-in user
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Use both idToken and accessToken to create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      setState(() {
        user = userCredential.user;
      });

      print('Signed in as: ${user!.email}');

      final email = user!.email ?? '';
      final savedRole = prefs.getString('role') ?? '';
      role = savedRole;
      final verifyResponse = await _authService.verifyGoogleUser(email: email, role: role);
      print('verify-google-user response: $verifyResponse'); // Debug print

      // Check if user is verified and token is present
      if (verifyResponse['verified'] != true || verifyResponse['token'] == null) {
        // Not authorized, show message and stop
        setState(() {
          _isLoading = false;
          _authErrorMessage = 'You are not authorized for this role.'; // Set error message
          user = null; // Clear user info
        });
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        return;
      }

      if (verifyResponse['token'] != null) {
        await prefs.setString('token', verifyResponse['token'].toString());
      }
      if (verifyResponse['role'] != null) {
        await prefs.setString('role', verifyResponse['role'].toString());
      }
      if (verifyResponse['id'] != null) {
        await prefs.setString('id', verifyResponse['id'].toString());
      }
      if (verifyResponse['gender'] != null) {
        await prefs.setString('gender', verifyResponse['gender'].toString());
      }
      if (verifyResponse['email'] != null) {
        await prefs.setString('email', verifyResponse['email'].toString());
      }
      if (verifyResponse['name'] != null) {
        await prefs.setString('name', verifyResponse['name'].toString());
      }

      // Print all stored values for debugging
      print('All SharedPreferences after login:');
      print('token: ${prefs.getString('token')}');
      print('role: ${prefs.getString('role')}');
      print('isLoggedIn: ${prefs.getBool('isLoggedIn')}');
      print('ID: ${prefs.getString('id')}');
      print('email: ${prefs.getString('email')}');
      print('name: ${prefs.getString('name')}');
      print('gender: ${prefs.getString('gender')}');
    
      // Step 3: Get FCM token and register
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print('Obtained FCM token: $fcmToken');
      if (fcmToken != null) {
        // Store FCM token in SharedPreferences
        await prefs.setString('fcm_token', fcmToken);
        final registerResponse = await _authService.registerFcmToken(
          fcmToken: fcmToken,
          email: email,
          id: verifyResponse['id'] ?? '',
          name: prefs.getString('name') ?? '',
          role: role,
          gender: prefs.getString('gender'),
        );
        print('register-fcm-token response: $registerResponse');

        // Set isLoggedIn to true after successful FCM registration
        await prefs.setBool('isLoggedIn', true);

        // Ask notification permission
        final settings = await FirebaseMessaging.instance.requestPermission();
        debugPrint('Notification permission status: ${settings.authorizationStatus}');
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          final savedRole = prefs.getString('role') ?? '';
          if (savedRole == 'student') {
            Navigator.of(context).pushReplacementNamed('/student-dashboard');
          } else if (savedRole == 'parent') {
            Navigator.of(context).pushReplacementNamed('/parent-dashboard');
          } else if (savedRole == 'warden') {
            Navigator.of(context).pushReplacementNamed('/warden-dashboard');
          } else if (savedRole == 'guard') {
            Navigator.of(context).pushReplacementNamed('/guard-dashboard');
          } else {
            print('Unknown role: $savedRole');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unknown role: "$savedRole", please try again.')),
            );
          }
        } else {
          print('Notification permission not granted');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission is required to proceed. Please enable notifications in your device settings.')),
          );
        }
      } else {
        print('FCM token is null, skipping FCM registration');
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in with Google: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> signOut() async {
    // Retrieve FCM token from SharedPreferences before sign out
    final prefs = await SharedPreferences.getInstance();
    final fcmToken = prefs.getString('fcm_token');
    if (fcmToken != null) {
      await _authService.deleteFcmToken(fcmToken: fcmToken);
      await prefs.remove('fcm_token');
    }
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    await prefs.remove('isLoggedIn');
    await prefs.remove('role');
    await prefs.remove('email');
    await prefs.remove('name');
    await prefs.remove('token');
    print('User signed out and SharedPreferences cleared');
    setState(() {
      user = null;
    });
    // After logout, go to role selection
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/role-selection');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Circular gradient background
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final colors = [
                Colors.blue.shade400,
                Colors.cyan.shade200,
                Colors.teal.shade100,
                Colors.lightBlue.shade100,
              ];
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.5 - _animation.value, 0.5 + _animation.value),
                    radius: 1.5,
                    colors: colors,
                    stops: [0.2, 0.5, 0.8, 1.0],
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              );
            },
          ),
          // Semi-transparent overlay for better contrast
          Container(
            color: Colors.white.withOpacity(0.3),
          ),
          // Main login content
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Add a medical college logo at the top
                    Image.asset(
                      'assets/images/logo.png', // Replace with your medical college logo
                      height: 100,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome to PIMS Medical College!',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 186, 28, 28), // Make text visible on dark overlay
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    if (_isLoading)
                      const CircularProgressIndicator(),
                    if (!_isLoading) ...[
                      if (_authErrorMessage != null) ...[
                        Text(
                          _authErrorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _authErrorMessage = null;
                            });
                          },
                          child: const Text('Try Again'),
                        ),
                      ] else if (user == null) ...[
                        TextButton(
                          onPressed: signInWithGoogle,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/google.png', // Add a Google logo asset for better UX
                                height: 24,
                              ),
                              const SizedBox(width: 12),
                              const Text('Sign in with Google'),
                            ],
                          ),
                        ),
                      ] else ...[
                        CircleAvatar(
                          backgroundImage: NetworkImage(user!.photoURL ?? ''),
                          radius: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user!.displayName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          user!.email ?? '',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final shouldLogout = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Logout'),
                                content: const Text('Are you sure you want to logout?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Logout'),
                                  ),
                                ],
                              ),
                            );
                            if (shouldLogout == true) {
                              await signOut();
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    const SizedBox(height: 40),
                  ],
                  ],
  
              ),
            ),
          ),
          ),
        ],
      ),
    );
  
  }
}