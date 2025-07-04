// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../models/data_models.dart';
import '../services/warden_service.dart';
 import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'leave_details_screen.dart'; 

class WardenDashboardScreen extends StatefulWidget {
  const WardenDashboardScreen({super.key});

  @override
  State<WardenDashboardScreen> createState() => _WardenDashboardScreenState();
}

class _WardenDashboardScreenState extends State<WardenDashboardScreen> with SingleTickerProviderStateMixin {
  List<LeaveRequest> _leaveRequests = [];
  String _filterOption = 'All';
  bool _isLoading = false;
  String? _error;

  late WardenService _wardenService;

  String _wardenName = '';
  String _wardenEmail = '';

  late TabController _tabController;

  Future<void> _loadWardenInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wardenName = prefs.getString('name') ?? '';
      _wardenEmail = prefs.getString('email') ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    _wardenService = WardenService(
      baseUrl: 'https://college-leave-backend.onrender.com/api',
    );
    _tabController = TabController(length: 2, vsync: this);
    _loadWardenInfo();
    _loadLeaveRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final leaves = await _wardenService.getPendingApplications();
      setState(() {
        _leaveRequests = leaves.map((leave) => LeaveRequest.fromJson(leave)).toList();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load leave requests.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = _leaveRequests
        .where((r) =>
            r.parentStatus.status == 'approved' &&
            (r.wardenStatus.status == 'pending'))
        .toList();

    final approvedCount = _leaveRequests
        .where((r) => r.wardenStatus.status == 'approved')
        .length;

    // Filtering for All tab
    List<LeaveRequest> filteredRequests = _leaveRequests;
    switch (_filterOption) {
      case 'Pending':
        filteredRequests = _leaveRequests
            .where((r) =>
                r.parentStatus.status == 'approved' &&
                (r.wardenStatus.status == 'pending'))
            .toList();
        break;
      case 'Approved':
        filteredRequests = _leaveRequests
            .where((r) => r.wardenStatus.status == 'approved')
            .toList();
        break;
      case 'Rejected':
        filteredRequests = _leaveRequests
            .where((r) => r.wardenStatus.status == 'rejected')
            .toList();
        break;
      default:
        filteredRequests = _leaveRequests;
    }

    List<LeaveRequest> pendingTabRequests = pendingRequests;

    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        title: const Text('Warden Dashboard'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
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
                await prefs.remove('student_name');
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Pending Tab: full dashboard
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome Card (refactored to match student dashboard)
                          Card(
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.orange,
                                    child: Icon(
                                      Icons.admin_panel_settings,
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
                                          'Welcome, $_wardenName',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _wardenEmail,
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

                          // Stats Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Pending Review',
                                  pendingRequests.length.toString(),
                                  Colors.orange,
                                  Icons.pending_actions,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Approved',
                                  approvedCount.toString(),
                                  Colors.green,
                                  Icons.check_circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Total',
                                  _leaveRequests.length.toString(),
                                  Colors.blue,
                                  Icons.list_alt,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Remove Dropdown filter and replace with section header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Leave Requests',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (pendingRequests.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${pendingRequests.length} pending',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Pending requests list
                          Expanded(
                            child: pendingTabRequests.isEmpty
                                ? Center(
                                    child: Text(
                                      'No pending leave requests to review.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadLeaveRequests,
                                    child: ListView.builder(
                                      itemCount: pendingTabRequests.length,
                                      itemBuilder: (context, index) {
                                        final request = pendingTabRequests[index];
                                        return _buildLeaveRequestCard(request);
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      // All Tab: only filter and filtered list
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              DropdownButton<String>(
                                value: _filterOption,
                                icon: const Icon(Icons.filter_list),
                                underline: Container(
                                  height: 2,
                                  color: Colors.orange,
                                ),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _filterOption = newValue!;
                                  });
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
                          const SizedBox(height: 12),
                          Expanded(
                            child: filteredRequests.isEmpty
                                ? Center(
                                    child: Text(
                                      _filterOption == 'All'
                                          ? 'No leave requests found.'
                                          : 'No $_filterOption leave requests found.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadLeaveRequests,
                                    child: ListView.builder(
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
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestCard(LeaveRequest request) {
    bool showActionButtons = request.parentStatus.status == 'approved' &&
        (request.wardenStatus.status == 'pending');

    // Document preview logic
    final hasDocument = request.attachmentPath != null && request.attachmentPath!.isNotEmpty;
    final previewUrl = hasDocument
        ? 'https://college-leave-backend.onrender.com/api/drive/${request.attachmentPath}'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          // Fetch full details and navigate to details screen
          try {
            setState(() {
              _isLoading = true;
            });
            final details = await _wardenService.getApplicationDetails(request.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LeaveDetailsScreen(rawJson: details),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to load application details.')),
            );
          } finally {
            setState(() {
              _isLoading = false;
            });
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Student Name: ${request.studentName}',
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
              if (request.attachmentPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          if (previewUrl != null) {
                            launchUrl(Uri.parse(previewUrl));
                          }
                        },
                        child: const Text(
                          'View attachment',
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

              if (request.parentStatus.reason != null && request.parentStatus.reason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Parent\'s Comment:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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

              if (request.wardenStatus.reason != null && request.wardenStatus.reason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Comment:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          request.wardenStatus.reason!,
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
    final ValueNotifier<bool> showError = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApproval ? 'Approve Leave' : 'Reject Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${request.studentId}'),
            Text('Reason: ${request.reason}'),
            Text('Duration: ${_formatDate(request.startDate)} to ${_formatDate(request.endDate)}'),
            if (request.parentStatus.reason != null && request.parentStatus.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Parent\'s Comment: ${request.parentStatus.reason}'),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: isApproval ? 'Comment (Optional)' : 'Reason for rejection *',
                hintText: isApproval 
                    ? 'e.g., Approved. Take care!'
                    : 'e.g., Need more documentation',
                border: const OutlineInputBorder(),
                errorText: !isApproval && showError.value && commentController.text.trim().isEmpty
                    ? 'Rejection reason is required'
                    : null,
              ),
              maxLines: 2,
              onChanged: (_) {
                if (!isApproval) showError.value = false;
              },
            ),
            if (!isApproval)
              ValueListenableBuilder<bool>(
                valueListenable: showError,
                builder: (context, value, child) {
                  return value
                      ? const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Rejection reason is required',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        )
                      : const SizedBox.shrink();
                },
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
              if (!isApproval && commentController.text.trim().isEmpty) {
                showError.value = true;
                return;
              }
              _handleApproval(request, isApproval, commentController.text.trim());
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
    try {
      setState(() {
        _isLoading = true;
      });
      await _wardenService.decideApplication(
        id: request.id,
        decision: isApproval ? 'approved' : 'rejected',
        rejectionReason: isApproval ? null : comment,
      );
      await _loadLeaveRequests();
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
          content: Text('Failed to update leave request.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

