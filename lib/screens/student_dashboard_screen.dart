import 'package:flutter/material.dart';
import '../models/data_models.dart'; 
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/leave_service.dart'; 
import 'package:google_sign_in/google_sign_in.dart';
import 'leave_details_screen.dart'; 
import '../services/auth_service.dart'; 
import 'package:flutter/services.dart';
import 'notifications_screen.dart'; 

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  List<LeaveRequest> _leaveRequests = [];
  String? _userEmail;
  String _studentName = ' ';
  String? _token;
  String? _gender;
  int _selectedTab = 0; 
  String _filterStatus = 'All'; 
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('email') ;
      _studentName = prefs.getString('name') ?? ' ';
      _token = prefs.getString('token');
      _gender = prefs.getString('gender');
    });
    await _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
    if (_token == null || _userEmail == null) {
      setState(() {
        _leaveRequests = [];
      });
      return;
    }
    try {
      final leaveService = LeaveService();
      final allLeaves = await leaveService.fetchAllLeaves(token: _token!);
      setState(() {
        _leaveRequests = allLeaves;
      });
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('401') || errorMsg.contains('Invalid or expired token')) {
        // Clear login state and redirect to login/role selection
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('isLoggedIn');
        await prefs.remove('token');
        await prefs.remove('role');
        await prefs.remove('email');
        await prefs.remove('name');
        await prefs.remove('student_name');
        await prefs.remove('gender');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired, please login again.')),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
        }
        return;
      }
      print('[StudentDashboardScreen] Error fetching leaves: $e');
      setState(() {
        _leaveRequests = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
          return false;
        }
        await SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.blue[50],
        appBar: AppBar(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          title: Text(_selectedTab == 0 ? 'Student Dashboard' : 'My Applications'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            if (_selectedTab == 0)
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                // Show confirmation dialog before logout
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
                  // Clear user session data and sign out
                  final prefs = await SharedPreferences.getInstance();
                  final fcmToken = prefs.getString('fcm_token');
                  if (fcmToken != null && fcmToken.isNotEmpty) {
                    try {
                      await AuthService().deleteFcmToken(fcmToken: fcmToken);
                    } catch (_) {}
                  }
                  await prefs.remove('user_email');
                  await prefs.setBool('isLoggedIn', false);
                  await prefs.remove('token');
                  await prefs.remove('role');
                  await prefs.remove('name');
                  await prefs.remove('email');
                  await prefs.remove('student_name');
                  await prefs.remove('gender');
                  // Sign out from Google as well
                  try {
                    await GoogleSignIn().signOut();
                  } catch (_) {}
                  // Navigate to login/role selection
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/role-selection',
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: _selectedTab == 0 ? _buildDashboardTab() : _buildApplicationsTab(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (idx) {
            setState(() {
              _selectedTab = idx;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'Applications',
            ),
          ],
        ),
      ),
    );
  }

  // --- Dashboard Tab: Only first 3 applications with timeline ---
  Widget _buildDashboardTab() {
    // Check if there is any leave with wardenStatus approved
    final LeaveRequest? approvedLeave = _leaveRequests
        .where((leave) => leave.wardenStatus.status == 'approved')
        .cast<LeaveRequest?>()
        .toList()
        .isNotEmpty
        ? _leaveRequests
            .where((leave) => leave.wardenStatus.status == 'approved')
            .first
        : null;
    final isQRActive = approvedLeave != null;

    return RefreshIndicator(
      onRefresh: _loadLeaveRequests,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Welcome Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue,
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_studentName ?? ""}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _userEmail ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Request Leave',
                    Icons.add_circle,
                    Colors.blue,
                    () {
                      Navigator.pushNamed(context, '/request-leave');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'My QR Code',
                    Icons.qr_code,
                    Colors.green,
                    isQRActive
                        ? () {
                            _showQRCode(approvedLeave);
                          }
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Leave Requests Section (first 3)
            const Text(
              'Recent Applications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (_leaveRequests.isEmpty)
              const Center(
                child: Text(
                  'No leave requests yet.\nTap "Request Leave" to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              )
            else
              ..._leaveRequests
                  .take(3)
                  .map((req) => _buildLeaveRequestCard(req, showTimeline: true))
                  ,
          ],
        ),
      ),
    );
  }

  // --- Applications Tab: All applications with filter ---
  Widget _buildApplicationsTab() {
    // Filtering logic
    List<LeaveRequest> filtered = _leaveRequests;
    if (_filterStatus != 'All') {
      filtered = _leaveRequests.where((leave) {
        final warden = leave.wardenStatus.status;
        final parent = leave.parentStatus.status;
        final guard = leave.guardStatus.status;
        if (_filterStatus == 'Parent Approved') {
          return parent == 'approved';
        } else if (_filterStatus == 'Warden Approved') {
          return warden == 'approved';
        } else if (_filterStatus == 'Guard Approved') {
          return guard == 'approved';
        }
        return true;
      }).toList();
    }

    return RefreshIndicator(
      onRefresh: _loadLeaveRequests,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter Row
            Row(
              children: [
                const Text(
                  'Filter:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterStatus,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Parent Approved', child: Text('Parent Approved')),
                    DropdownMenuItem(value: 'Warden Approved', child: Text('Warden Approved')),
                    DropdownMenuItem(value: 'Guard Approved', child: Text('Guard Approved')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterStatus = val!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Center(
                child: Text(
                  'No applications found for selected filter.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: filtered
                      .map((req) => _buildLeaveRequestCard(req, showTimeline: true))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Modified to optionally show timeline ---
  Widget _buildLeaveRequestCard(LeaveRequest request, {bool showTimeline = false}) {
    Color statusColor;
    String statusText;

    // Determine status based on adminStatus, wardenStatus, parentStatus
    final admin = request.adminStatus.status ?? '';
    final warden = request.wardenStatus.status ?? '';
    final parent = request.parentStatus.status ?? '';

    if (admin == 'stopped') {
      statusColor = Colors.red;
      statusText = 'Stopped by Admin';
    } else if (warden == 'approved') {
      statusColor = Colors.green;
      statusText = 'Approved by Warden';
    } else if (warden == 'rejected') {
      statusColor = Colors.red;
      statusText = 'Rejected by Warden';
    } else if (parent == 'approved') {
      statusColor = Colors.blue;
      statusText = 'Waiting for Warden Approval';
    } else if (parent == 'rejected') {
      statusColor = Colors.red;
      statusText = 'Rejected by Parent';
    } else {
      statusColor = Colors.orange;
      statusText = 'Waiting for Parent Approval';
    }

    return GestureDetector(
      onTap: () async {
        if (_token == null || (request.id ?? '').isEmpty) return;
        try {
          final leaveService = LeaveService();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
          final rawJson = await leaveService.fetchLeaveById(
            token: _token!,
            leaveId: request.id ?? '',
          );
          Navigator.pop(context); // Remove loading dialog
          // Pass only the 'leave' field from the fetched JSON to the details screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LeaveDetailsScreen(
                rawJson: (rawJson is Map<String, dynamic> && rawJson.containsKey('leave'))
                    ? rawJson['leave'] as Map<String, dynamic>
                    : null,
              ),
            ),
          );
        } catch (e) {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      request.reason ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'From: ${_formatDate(request.startDate)}',
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                'To: ${_formatDate(request.endDate)}',
                style: const TextStyle(color: Colors.grey),
              ),
              if (showTimeline)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: _buildSimpleStatusTracker(request),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Simple horizontal tracker widget ---
  Widget _buildSimpleStatusTracker(LeaveRequest leave) {
    // Only show Admin if rejected/stopped
    final showAdmin = leave.adminStatus.status == 'rejected' || leave.adminStatus.status == 'stopped';

    final stages = [
      {
        'label': 'Parent',
        'status': leave.parentStatus.status,
        'date': leave.parentStatus.decidedAt ?? leave.createdAt
      },
      {
        'label': 'Warden',
        'status': leave.wardenStatus.status,
        'date': leave.wardenStatus.decidedAt ?? leave.createdAt
      },
      {
        'label': 'Guard',
        'status': leave.guardStatus.status,
        'date': leave.guardStatus.decidedAt ?? leave.createdAt
      },
    ];

    // Find current stage index
    int currentStage = 0;
    for (int i = 0; i < stages.length; i++) {
      final status = stages[i]['status'] as String?;
      if (status == 'pending') {
        currentStage = i;
        break;
      }
      if (status == 'rejected' || status == 'stopped') {
        currentStage = i;
        break;
      }
      if (status == 'approved') {
        currentStage = i + 1;
      }
    }

    Color getColor(int idx, String? status) {
      if (status == 'rejected' || status == 'stopped') return Colors.red;
      if (idx < currentStage) return Colors.green;
      if (idx == currentStage) return Colors.blue;
      return Colors.grey[400]!;
    }

    Widget buildDot(int idx, String label, String? status, DateTime? date) {
      final color = getColor(idx, status);
      return Column(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Icon(
              status == 'approved'
                  ? Icons.check
                  : (status == 'rejected' || status == 'stopped')
                      ? Icons.close
                      : Icons.circle,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: idx == currentStage ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if ((status == 'approved' || status == 'rejected' || status == 'stopped') && date != null)
            Text(
              _formatDateTime(date),
              style: TextStyle(
                fontSize: 10,
                color: status == 'approved' ? Colors.green : Colors.red,
              ),
            ),
        ],
      );
    }

    List<Widget> tracker = List.generate(stages.length * 2 - 1, (i) {
      if (i.isEven) {
        final idx = i ~/ 2;
        final stage = stages[idx];
        return buildDot(
          idx,
          stage['label'] as String,
          stage['status'] as String?,
          stage['date'] as DateTime?,
        );
      } else {
        // Connector line
        final leftIdx = (i - 1) ~/ 2;
        final leftStatus = stages[leftIdx]['status'] as String?;
        final color = (leftStatus == 'approved' || leftStatus == 'rejected' || leftStatus == 'stopped')
            ? getColor(leftIdx, leftStatus)
            : Colors.grey[400];
        return Expanded(
          child: Container(
            height: 2,
            color: color,
          ),
        );
      }
    });

    // Optionally add Admin rejected/stopped at the end
    if (showAdmin) {
      tracker.add(Expanded(
        child: Row(
          children: [
            const SizedBox(width: 8),
            Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Admin',
                  style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                ),
                if (leave.adminStatus.decidedAt != null)
                  Text(
                    _formatDateTime(leave.adminStatus.decidedAt!),
                    style: const TextStyle(fontSize: 10, color: Colors.red),
                  )
                else if (leave.createdAt != null)
                  Text(
                    _formatDateTime(leave.createdAt),
                    style: const TextStyle(fontSize: 10, color: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: tracker,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }


  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showQRCode([LeaveRequest? approvedLeave]) {
    // If no approvedLeave, do nothing (should not be called)
    if (approvedLeave == null) return;

    final qrData = _generateQRData(approvedLeave);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code to verify leave approval',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Leave ID: ${approvedLeave.id}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _generateQRData(LeaveRequest approvedLeave) {
    // Only called if approvedLeave is not null
    Map<String, dynamic> qrData = {
      'studentId': approvedLeave.studentId,
      'leaveId': approvedLeave.id,
    };
    return json.encode(qrData);
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback? onPressed, // <-- Make nullable
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}