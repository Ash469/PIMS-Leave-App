import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/data_models.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  int _pressedIndex = -1;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    _logoController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Animated blurred overlay for depth
          AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 900),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Semi-transparent gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.18),
                  Colors.purple.withOpacity(0.13),
                  Colors.white.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Glassmorphism Content Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(screenWidth * 0.05),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      width: screenWidth > 450 ? 430 : screenWidth * 0.9,
                      padding: EdgeInsets.symmetric(
                        vertical: screenHeight * 0.05,
                        horizontal: screenWidth * 0.08,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.10),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated App Logo/Title with glowing border
                          ScaleTransition(
                            scale: _logoScale,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.25),
                                    blurRadius: 32,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.blueAccent.withOpacity(0.18),
                                  width: 2.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: screenWidth * 0.25,
                                  height: screenWidth * 0.25,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          Text(
                            'Prasad Institute of Medical Sciences',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 219, 46, 46),
                              letterSpacing: 0.7,
                              shadows: const [
                                Shadow(
                                  color: Colors.white,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            'Empowering Education & Care',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: screenWidth * 0.035,
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.04),
                          Text(
                            'Who are you?',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.03),
                          // Role Selection Buttons
                          _buildRoleButton(
                            context,
                            'Student',
                            Icons.school,
                            Colors.blue,
                            UserRole.student,
                            0,
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildRoleButton(
                            context,
                            'Parent',
                            Icons.family_restroom,
                            Colors.green,
                            UserRole.parent,
                            1,
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildRoleButton(
                            context,
                            'Warden',
                            Icons.admin_panel_settings,
                            Colors.orange,
                            UserRole.warden,
                            2,
                          ),
                          SizedBox(height: screenHeight * 0.02),
                          _buildRoleButton(
                            context,
                            'Guard',
                            Icons.security,
                            Colors.purple,
                            UserRole.guard,
                            3,
                          ),
                        ],
                      ),
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

  Widget _buildRoleButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    UserRole role,
    int index,
  ) {
    final bool isPressed = _pressedIndex == index;
    return Listener(
      onPointerDown: (_) => setState(() => _pressedIndex = index),
      onPointerUp: (_) => setState(() => _pressedIndex = -1),
      child: AnimatedScale(
        scale: isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ElevatedButton(
          onPressed: () async {
            setState(() => _pressedIndex = index);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('role', role.name);
            await Future.delayed(const Duration(milliseconds: 120));
            setState(() => _pressedIndex = -1);
            Navigator.pushNamed(
              context,
              '/login',
              arguments: role,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}