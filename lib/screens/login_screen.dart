import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'dart:developer' as dev;

// A reusable glassmorphic container for a modern UI effect
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  const GlassmorphicContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(25.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// New screen to force user to enter their College ID
class CollegeIdScreen extends StatefulWidget {
  const CollegeIdScreen({super.key});

  @override
  State<CollegeIdScreen> createState() => _CollegeIdScreenState();
}

class _CollegeIdScreenState extends State<CollegeIdScreen> {
  final TextEditingController _collegeIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Return the entered ID to the previous screen
      Navigator.of(context).pop(_collegeIdController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade400, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: GlassmorphicContainer(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png', // Using the same logo
                      height: 80,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Verification Required',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Please enter your College ID to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _collegeIdController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'College ID',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Your unique college ID',
                        hintStyle: const TextStyle(color: Colors.white38),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'College ID cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.white.withOpacity(0.9),
                        foregroundColor: Colors.deepPurple,
                         shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class LoginScreen extends StatefulWidget {
  final dynamic role;
  const LoginScreen({super.key, this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  User? user;
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  late SharedPreferences prefs;
  String role = '';
  String? _authErrorMessage;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadRoleFromPrefs();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadRoleFromPrefs() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? '';
    });
    dev.log('Loaded role from prefs: $role');
  }

  // Refactored method to handle post-verification logic
  Future<void> _handleSuccessfulVerification(
      Map<String, dynamic> verifyResponse,
      {required String emailForFcm}) async {
    // Check if user is verified and token is present
    if (verifyResponse['verified'] != true ||
        verifyResponse['token'] == null) {
      // Not authorized, show message and stop
      setState(() {
        _isLoading = false;
        _authErrorMessage = 'You are not authorized for this role.';
        user = null; // Clear user info
      });
      await FirebaseAuth.instance.signOut().catchError((_) {});
      await GoogleSignIn().signOut().catchError((_) {});
      return;
    }

    // Store user data from the response
    await prefs.setString('token', verifyResponse['token'].toString());
    await prefs.setString('role', verifyResponse['role'].toString());
    await prefs.setString('id', verifyResponse['id'].toString());
    await prefs.setString('gender', verifyResponse['gender'].toString());
    await prefs.setString('email', verifyResponse['email'].toString());
    await prefs.setString('name', verifyResponse['name'].toString());

    dev.log('All SharedPreferences after login:');
    dev.log('token: ${prefs.getString('token')}');
    dev.log('role: ${prefs.getString('role')}');
    dev.log('ID: ${prefs.getString('id')}');

    // Get FCM token and register
    dev.log('Requesting notification permission...');
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    dev.log('Notification permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      dev.log('👍Obtained FCM token: $fcmToken');
      if (fcmToken != null) {
        await prefs.setString('fcm_token', fcmToken);
        final registerResponse = await _authService.registerFcmToken(
          fcmToken: fcmToken,
          email: emailForFcm,
          id: verifyResponse['id'] ?? '',
          name: prefs.getString('name') ?? '',
          role: prefs.getString('role') ?? '',
          gender: prefs.getString('gender'),
        );
        dev.log('register-fcm-token response: $registerResponse');
      }
      await prefs.setBool('isLoggedIn', true);

      // Navigate to the correct dashboard
      final savedRole = prefs.getString('role') ?? '';
      if (!mounted) return;
      switch (savedRole) {
        case 'student':
          Navigator.of(context).pushReplacementNamed('/student-dashboard');
          break;
        case 'parent':
          Navigator.of(context).pushReplacementNamed('/parent-dashboard');
          break;
        case 'warden':
          Navigator.of(context).pushReplacementNamed('/warden-dashboard');
          break;
        case 'guard':
          Navigator.of(context).pushReplacementNamed('/guard-dashboard');
          break;
        default:
          dev.log('Unknown role: $savedRole');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Unknown role: "$savedRole", please try again.')),
          );
      }
    } else {
      dev.log('Notification permission not granted');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Notification permission is required. Please enable it in settings.')),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _authErrorMessage = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User cancelled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      setState(() {
        user = userCredential.user;
      });

      dev.log('Signed in as: ${user!.email}');

      final email = user!.email ?? '';
      final savedRole = prefs.getString('role') ?? '';
      role = savedRole;
      final verifyResponse =
          await _authService.verifyGoogleUser(email: email, role: role);
      dev.log('verify-google-user response: $verifyResponse');

      // Use the refactored handler
      await _handleSuccessfulVerification(verifyResponse, emailForFcm: email);
    } catch (e) {
      dev.log('Error signing in with Google: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Updated method for Apple Sign In
  Future<void> signInWithApple() async {
    setState(() {
      _isLoading = true;
      _authErrorMessage = null;
    });

    try {
      // Real Apple Sign In on Apple devices
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      dev.log('Apple credential received: ${credential.userIdentifier}');


      // After successful Apple sign-in, navigate to new screen to get College ID
      if (!mounted) return;
      final String? collegeId = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CollegeIdScreen()),
      );

      if (collegeId == null || collegeId.isEmpty) {
        // User somehow dismissed the screen without entering an ID, or returned null
        setState(() => _isLoading = false);
        return;
      }

      dev.log('User entered College ID: $collegeId');

      // Send college ID and role to the backend for verification
      final savedRole = prefs.getString('role') ?? '';
      final verifyResponse = await _authService.verifyGoogleUser(
          email: collegeId, role: savedRole); // As requested, using the same route
      dev.log('verify-apple-user (via google-route) response: $verifyResponse');

      // Use the refactored handler
      // We pass the collegeId as the `emailForFcm` as the actual Apple email might be private
      await _handleSuccessfulVerification(verifyResponse, emailForFcm: collegeId);

    } catch (e) {
      dev.log('Error signing in with Apple: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> signOut() async {
    final fcmToken = prefs.getString('fcm_token');
    if (fcmToken != null) {
      await _authService.deleteFcmToken(fcmToken: fcmToken);
      await prefs.remove('fcm_token');
    }
    await FirebaseAuth.instance.signOut().catchError((_) {});
    await GoogleSignIn().signOut().catchError((_) {});
    await prefs.clear(); // Clear all prefs on logout for safety
    dev.log('User signed out and SharedPreferences cleared');
    setState(() {
      user = null;
    });
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/role-selection');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Gradient Background
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade400, Colors.blue.shade600],
                    begin: Alignment(_animation.value, -1.0),
                    end: Alignment(-_animation.value, 1.0),
                  ),
                ),
              );
            },
          ),
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GlassmorphicContainer(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 100,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome to Ease Exit',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Prasad Institute of Medical Sciences',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        if (_isLoading)
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        if (!_isLoading) ...[
                          if (_authErrorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(15)
                              ),
                              child: Text(
                                _authErrorMessage!,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _authErrorMessage = null;
                                });
                              },
                              child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ] else if (user == null) ...[
                            // Google Sign In Button
                            ElevatedButton.icon(
                              onPressed: signInWithGoogle,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 8,
                                shadowColor: Colors.black.withOpacity(0.4)
                              ),
                              icon: Image.network(
                                'https://developers.google.com/identity/images/g-logo.png',
                                height: 24,
                              ),
                              label: const Text('Sign in with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 15),
                            // Apple Sign In Button (shows on Apple platforms only)
                            if (Platform.isIOS || Platform.isMacOS)
                              ElevatedButton.icon(
                                onPressed: signInWithApple,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.4)
                                ),
                                icon: const Icon(Icons.apple, color: Colors.white),
                                label: const Text('Sign in with Apple', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                          ] else ...[
                            CircleAvatar(
                              backgroundImage: NetworkImage(user!.photoURL ?? ''),
                              radius: 40,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              user!.displayName ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.white),
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
                                    content: const Text(
                                        'Are you sure you want to logout?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
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
                                backgroundColor: Colors.redAccent.withOpacity(0.8),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
