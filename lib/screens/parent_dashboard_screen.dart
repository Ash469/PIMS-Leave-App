import 'package:flutter/material.dart';
import '../services/parent_service.dart';
import '../models/data_models.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- Add this import
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart'; // <-- Add this import
import 'package:flutter/services.dart'; // Add this import
import 'leave_details_screen.dart'; // <-- Add this import
import 'notifications_screen.dart'; // <-- Add this import
import '../services/leave_service.dart'; // <-- Add this import

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  List<LeaveRequest> _leaveRequests = [];
  String _filterOption = 'All';
  int _selectedTab = 0;
  bool _loading = true;
  String? _token;
  String? _userEmail;
  String? _Name;
  DateTime? _lastBackPressed; // Add this field
  List<Map<String, dynamic>> _wardConcerns = []; // Add this field
  final ScrollController _dashboardScrollController = ScrollController(); // Add this field

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchApplications();
  }

  Future<void> _loadTokenAndFetchApplications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
      _userEmail = prefs.getString('email') ;
      _Name = prefs.getString('name') ?? 'Parent';
    });
    await _fetchApplications();
    await _fetchWardConcerns(); // Fetch ward concerns
  }

  Future<void> _fetchApplications() async {
    setState(() => _loading = true);
    try {
      if (_token == null || _token!.isEmpty) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authentication token found. Please log in again.')),
        );
        return;
      }
      final leaves = await ParentService.fetchApplications(token: _token!);
      setState(() {
        _leaveRequests = leaves;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load applications')),
      );
    }
  }

  Future<void> _fetchWardConcerns() async {
    try {
      if (_token == null || _token!.isEmpty) return;
      final concerns = await ParentService.fetchWardConcerns(token: _token!);
      setState(() {
        _wardConcerns = concerns;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load ward concerns')),
      );
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
        backgroundColor: Colors.green[50],
        appBar: AppBar(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          title: const Text('Parent Dashboard'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
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
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                Navigator.pushNamed(context, '/parent-profile');
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
                  await prefs.remove('email');
                  await prefs.remove('name');
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
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildTabContent(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (idx) => setState(() => _selectedTab = idx),
          selectedItemColor: Colors.green,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'All Applications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.report_problem),
              label: 'All Concerns',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildAllApplicationsTab();
      case 2:
        return _buildAllConcernsTab();
      default:
        return Container();
    }
  }

  Widget _buildDashboardTab() {
    final recentRequests = _leaveRequests.take(2).toList(); // Show only 2 applications
    final recentConcerns = _wardConcerns.take(2).toList(); // Show only 2 concerns

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchApplications();
        await _fetchWardConcerns(); // Refresh concerns
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          controller: _dashboardScrollController,
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
                      backgroundColor: Colors.green,
                      child: Icon(
                        Icons.family_restroom,
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
                            'Welcome, ${_Name ?? "Parent"}',
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

            // Recent Applications section (limited to 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Applications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedTab = 1;
                    });
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_leaveRequests.isEmpty)
              const Center(
                child: Text(
                  'No leave applications yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            else
              ...recentRequests.map(_buildLeaveRequestCard).toList(),

            // Ward Concerns section (limited to 2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ward Concerns',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedTab = 2;
                    });
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_wardConcerns.isEmpty)
              const Center(
                child: Text(
                  'No concerns reported yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            else
              ...recentConcerns.map(_buildConcernCard).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllApplicationsTab() {
    List<LeaveRequest> filteredRequests = _leaveRequests;
    switch (_filterOption) {
      case 'Pending':
        filteredRequests = _leaveRequests
            .where((r) => r.parentStatus.status == 'pending')
            .toList();
        break;
      case 'Approved':
        filteredRequests = _leaveRequests
            .where((r) => r.parentStatus.status == 'approved')
            .toList();
        break;
      case 'Rejected':
        filteredRequests = _leaveRequests
            .where((r) => r.parentStatus.status == 'rejected')
            .toList();
        break;
      case 'Parent Approved':
        filteredRequests = _leaveRequests
            .where((r) => r.parentStatus.status == 'approved')
            .toList();
        break;
      case 'Warden Approved':
        filteredRequests = _leaveRequests
            .where((r) => r.wardenStatus.status == 'approved')
            .toList();
        break;
      case 'Guard Approved':
        filteredRequests = _leaveRequests
            .where((r) => r.guardStatus.status == 'approved')
            .toList();
        break;
      default:
        filteredRequests = _leaveRequests;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Applications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _filterOption,
                icon: const Icon(Icons.filter_list),
                underline: Container(
                  height: 2,
                  color: Colors.green,
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    _filterOption = newValue!;
                  });
                },
                items: <String>[
                  'All',
                  'Parent Approved',
                  'Warden Approved',
                  'Guard Approved'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchApplications,
              child: filteredRequests.isEmpty
                  ? Center(
                      child: Text(
                        _filterOption == 'All'
                            ? 'No leave requests from your child yet.'
                            : 'No $_filterOption leave requests found.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) {
                        final request = filteredRequests[index];
                        return _buildLeaveRequestCard(request);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllConcernsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All Concerns',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchWardConcerns,
              child: _wardConcerns.isEmpty
                  ? const Center(
                      child: Text(
                        'No concerns reported yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _wardConcerns.length,
                      itemBuilder: (context, index) {
                        final concern = _wardConcerns[index];
                        return _buildConcernCard(concern);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestCard(LeaveRequest request) {
    Color statusColor;
    String statusText;
    bool showActionButtons = false;

    // Use parentStatus.status string from JSON for status logic
    switch (request.parentStatus.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending Your Approval';
        showActionButtons = true;
        break;
      case 'approved':
        statusColor = Colors.blue;
        statusText = 'Approved by You';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejected by You';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Status: ${request.parentStatus.status}';
    }

    return GestureDetector(
      onTap: () async {
        if (_token == null || (request.id ?? '').isEmpty) return;
        try {
          if (!mounted) return;
          print('[ParentDashboard] Fetching leave details for id: ${request.id}');
          print('[ParentDashboard] Using token: $_token');
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
          final leaveService = LeaveService();
          final rawJson = await leaveService.fetchLeaveById(
            token: _token!,
            leaveId: request.id ?? '',
          );
          print('[ParentDashboard] API response for leave details: $rawJson');
          if (!mounted) return;
          Navigator.pop(context); // Remove loading dialog
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
          if (mounted) {
            Navigator.pop(context); // Remove loading dialog if present
            print('[ParentDashboard] Error fetching leave details: $e');
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to fetch leave details.\n${e.toString()}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
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
                      request.reason,
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
                'Student : ${request.studentName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'From: ${_formatDate(request.startDate)}',
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                'To: ${_formatDate(request.endDate)}',
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                'Duration: ${request.endDate.difference(request.startDate).inDays + 1} day(s)',
                style: const TextStyle(color: Colors.grey),
              ),
              if (request.attachmentPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () async {
                          final url = Uri.parse('https://college-leave-backend.onrender.com/api/drive/${request.attachmentPath}');
                          try {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open attachment.')),
                            );
                          }
                        },
                        child: const Text(
                          'View Attachment',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Show parent's comment if present in parentStatus.reason
              if (request.parentStatus.reason != null && request.parentStatus.reason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Comment:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          request.parentStatus.reason!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              if (showActionButtons)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApprovalDialog(request, true),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApprovalDialog(request, false),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showApprovalDialog(LeaveRequest request, bool isApproval) {
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApproval ? 'Approve Leave' : 'Reject Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student ID: ${request.studentId}'),
            Text('Reason: ${request.reason}'),
            Text('Duration: ${_formatDate(request.startDate)} to ${_formatDate(request.endDate)}'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: isApproval ? 'Comment (Optional)' : 'Reason for rejection',
                hintText: isApproval 
                    ? 'e.g., Take care, Get well soon'
                    : 'e.g., Need more specific reason',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _handleApproval(request, isApproval, commentController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproval ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isApproval ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _handleApproval(LeaveRequest request, bool isApproval, String comment) async {
    if (_token == null) return;
    try {
      await ParentService.sendParentDecision(
        parentToken: request.parentToken ?? '', // parentToken must be present in LeaveRequest
        decision: isApproval ? 'approved' : 'rejected',
        token: _token!,
      );
      await _fetchApplications(); // Refresh list after decision
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApproval 
                ? 'Leave request approved successfully!'
                : 'Leave request rejected.',
          ),
          backgroundColor: isApproval ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${isApproval ? 'approve' : 'reject'} leave request.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildConcernCard(Map<String, dynamic> concern) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              concern['description'] ?? 'No description provided',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Student: ${concern['studentName']}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              'Batch: ${concern['batch']}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'Created At: ${DateTime.parse(concern['createdAt']).toLocal()}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (concern['documentUrl'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () async {
                        final url = Uri.parse('https://college-leave-backend.onrender.com/api/drive/${concern['documentUrl']}');
                        try {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open attachment.')),
                          );
                        }
                      },
                      child: const Text(
                        'View Attachment',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}


