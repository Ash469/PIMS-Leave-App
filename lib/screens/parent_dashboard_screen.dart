import 'package:flutter/material.dart';
import '../services/parent_service.dart';
import '../models/data_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';
import 'leave_details_screen.dart';
import 'notifications_screen.dart';
import '../services/leave_service.dart';
import 'dart:developer' as dev;

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
  DateTime? _lastBackPressed;
  List<Map<String, dynamic>> _wardConcerns = [];
  final ScrollController _dashboardScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchApplications();
  }

  Future<void> _loadTokenAndFetchApplications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
      _userEmail = prefs.getString('email');
      _Name = prefs.getString('name') ?? 'Parent';
    });
    await _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      if (_token == null || _token!.isEmpty) {
        throw Exception('No authentication token found.');
      }
      // Fetch both data in parallel
      final results = await Future.wait([
        ParentService.fetchApplications(token: _token!),
        ParentService.fetchWardConcerns(token: _token!),
      ]);
      setState(() {
        _leaveRequests = results[0] as List<LeaveRequest>;
        _wardConcerns = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: ${e.toString()}')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
          return;
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
          title: const Text('Parent Dashboard'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () {
                Navigator.pushNamed(context, '/parent-profile');
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
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
                  final prefs = await SharedPreferences.getInstance();
                  final fcmToken = prefs.getString('fcm_token');
                  if (fcmToken != null && fcmToken.isNotEmpty) {
                    try {
                      await AuthService().deleteFcmToken(fcmToken: fcmToken);
                    } catch (_) {}
                  }
                  await prefs.clear();
                  try {
                    await GoogleSignIn().signOut();
                  } catch (_) {}
                  if (!mounted) return;
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
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_outlined),
               activeIcon: Icon(Icons.list_alt),
              label: 'Applications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.report_problem_outlined),
              activeIcon: Icon(Icons.report_problem),
              label: 'Concerns',
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
    final recentRequests = _leaveRequests.take(2).toList();
    final recentConcerns = _wardConcerns.take(2).toList();
    final pendingCount = _leaveRequests.where((r) => r.parentStatus.status == 'pending').length;
    final approvedCount = _leaveRequests.where((r) => r.parentStatus.status == 'approved').length;

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        controller: _dashboardScrollController,
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.green.shade500, Colors.teal.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${_Name ?? "Parent"}!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                 Text(
                  _userEmail ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat Cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Pending Actions', pendingCount.toString(), Icons.pending_actions, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Approved Leaves', approvedCount.toString(), Icons.check_circle, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Total Concerns', _wardConcerns.length.toString(), Icons.report, Colors.red)),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Applications section
          _buildSectionHeader('Recent Applications', () => setState(() => _selectedTab = 1)),
          if (recentRequests.isEmpty)
            _buildEmptyState('No recent leave applications.')
          else
            ...recentRequests.map(_buildLeaveRequestCard).toList(),

          const SizedBox(height: 24),

          // Ward Concerns section
          _buildSectionHeader('Recent Ward Concerns', () => setState(() => _selectedTab = 2)),
          if (recentConcerns.isEmpty)
            _buildEmptyState('No recent concerns reported.')
          else
            ...recentConcerns.map(_buildConcernCard).toList(),
        ],
      ),
    );
  }

  Widget _buildAllApplicationsTab() {
    List<LeaveRequest> filteredRequests = _leaveRequests;
    if (_filterOption != 'All') {
      filteredRequests = _leaveRequests.where((r) => r.parentStatus.status == _filterOption.toLowerCase()).toList();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'All Applications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _filterOption,
                  icon: const Icon(Icons.filter_list),
                  underline: Container(),
                  onChanged: (String? newValue) {
                    setState(() => _filterOption = newValue!);
                  },
                  items: <String>['All', 'Pending', 'Approved', 'Rejected']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: filteredRequests.isEmpty
                  ? _buildEmptyState('No $_filterOption applications found.')
                  : ListView.builder(
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) => _buildLeaveRequestCard(filteredRequests[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllConcernsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'All Concerns',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: _wardConcerns.isEmpty
                  ? _buildEmptyState('No concerns reported yet.')
                  : ListView.builder(
                      itemCount: _wardConcerns.length,
                      itemBuilder: (context, index) => _buildConcernCard(_wardConcerns[index]),
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
    bool showActionButtons = request.parentStatus.status == 'pending';

    switch (request.parentStatus.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending Your Approval';
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (_token == null || (request.id).isEmpty) return;
          try {
            if (!mounted) return;
            dev.log('[ParentDashboard] Fetching leave details for id: ${request.id}');
            dev.log('[ParentDashboard] Using token: $_token');
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );
            final leaveService = LeaveService();
            final rawJson = await leaveService.fetchLeaveById(
              token: _token!,
              leaveId: request.id,
            );
            dev.log('[ParentDashboard] API response for leave details: $rawJson');
            if (!mounted) return;
            Navigator.pop(context); // Remove loading dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LeaveDetailsScreen(
                  rawJson: (rawJson.containsKey('leave'))
                      ? rawJson['leave'] as Map<String, dynamic>
                      : null,
                ),
              ),
            );
          } catch (e) {
            if (mounted) {
              Navigator.pop(context); // Remove loading dialog if present
              dev.log('[ParentDashboard] Error fetching leave details: $e');
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Error'),
                  content:
                      Text('Failed to fetch leave details.\n${e.toString()}'),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildInfoRow(Icons.person_outline, 'Student: ${request.studentName}'),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.calendar_today_outlined, 'From: ${_formatDate(request.startDate)} To: ${_formatDate(request.endDate)}'),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.timer_outlined, 'Duration: ${request.endDate.difference(request.startDate).inDays + 1} day(s)'),
              
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

  Widget _buildConcernCard(Map<String, dynamic> concern) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              concern['description'] ?? 'No description provided',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _buildInfoRow(Icons.person_outline, 'Student: ${concern['studentName']}'),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.group_outlined, 'Batch: ${concern['batch']}'),
            const SizedBox(height: 4),
             _buildInfoRow(Icons.calendar_today_outlined, 'Created At: ${_formatDate(DateTime.parse(concern['createdAt']))}'),
          ],
        ),
      ),
    );
  }

  // Helper Widgets for UI
  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: onViewAll,
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade700))),
      ],
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
          children: [
            Text('Are you sure you want to ${isApproval ? 'approve' : 'reject'} this request?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: isApproval ? 'Comment (Optional)' : 'Reason for rejection',
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

  void _handleApproval(
      LeaveRequest request, bool isApproval, String comment) async {
    if (_token == null) return;
    try {
      await ParentService.sendParentDecision(
        parentToken: request.parentToken ?? '',
        decision: isApproval ? 'approved' : 'rejected',
        token: _token!,
      );
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApproval
              ? 'Leave request approved successfully!'
              : 'Leave request rejected.'),
          backgroundColor: isApproval ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${isApproval ? 'approve' : 'reject'} leave request.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
