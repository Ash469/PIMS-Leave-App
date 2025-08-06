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

class _WardenDashboardScreenState extends State<WardenDashboardScreen> {
  List<LeaveRequest> _leaveRequests = [];
  String _filterOption = 'All';
  bool _isLoading = false;
  String? _error;
  int _selectedTab = 0;

  late WardenService _wardenService;

  String _wardenName = '';
  String _wardenEmail = '';

  @override
  void initState() {
    super.initState();
    _wardenService = WardenService(
      baseUrl: 'https://college-leave-backend.onrender.com/api',
    );
    _loadWardenInfo();
    _loadLeaveRequests();
  }

  Future<void> _loadWardenInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wardenName = prefs.getString('name') ?? 'Warden';
      _wardenEmail = prefs.getString('email') ?? '';
    });
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        title: Text(_selectedTab == 0 ? 'Warden Dashboard' : 'All Applications'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
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
                await prefs.clear();
                try {
                  await GoogleSignIn().signOut();
                } catch (_) {}
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildTabContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (idx) => setState(() => _selectedTab = idx),
        selectedItemColor: Colors.deepOrange.shade700,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'All',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildAllApplicationsTab();
      default:
        return Container();
    }
  }

  Widget _buildDashboardTab() {
    final pendingRequests = _leaveRequests.where((r) => r.parentStatus.status == 'approved' && r.wardenStatus.status == 'pending').toList();
    final approvedToday = _leaveRequests.where((r) => r.wardenStatus.status == 'approved' && r.wardenStatus.decidedAt != null && r.wardenStatus.decidedAt!.isAfter(DateTime.now().subtract(const Duration(days: 1)))).length;
    final totalProcessed = _leaveRequests.where((r) => r.wardenStatus.status != 'pending').length;

    return RefreshIndicator(
      onRefresh: _loadLeaveRequests,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.deepOrange.shade500, Colors.orange.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $_wardenName',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _wardenEmail,
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat Cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Pending Review', pendingRequests.length.toString(), Icons.pending_actions, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Approved Today', approvedToday.toString(), Icons.check_circle, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Total Processed', totalProcessed.toString(), Icons.list_alt, Colors.blue)),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Applications section
          _buildSectionHeader('Pending Your Approval', () {}),
          if (pendingRequests.isEmpty)
            _buildEmptyState('No pending requests to review.')
          else
            ...pendingRequests.map(_buildLeaveRequestCard).toList(),
        ],
      ),
    );
  }

  Widget _buildAllApplicationsTab() {
    List<LeaveRequest> filteredRequests = _leaveRequests;
    if (_filterOption != 'All') {
      filteredRequests = _leaveRequests.where((r) => r.wardenStatus.status == _filterOption.toLowerCase()).toList();
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
                const Text('All Applications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _filterOption,
                  icon: const Icon(Icons.filter_list),
                  underline: Container(),
                  onChanged: (String? newValue) {
                    setState(() => _filterOption = newValue!);
                  },
                  items: <String>['All', 'Pending', 'Approved', 'Rejected']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadLeaveRequests,
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

  Widget _buildLeaveRequestCard(LeaveRequest request) {
    bool showActionButtons = request.parentStatus.status == 'approved' && request.wardenStatus.status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          try {
            setState(() => _isLoading = true);
            final details = await _wardenService.getApplicationDetails(request.id);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LeaveDetailsScreen(rawJson: details)),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to load application details.')),
            );
          } finally {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.reason, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Student: ${request.studentName}', style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                'From: ${_formatDate(request.startDate)} To: ${_formatDate(request.endDate)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              if (request.parentStatus.reason != null && request.parentStatus.reason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Parent Comment: ${request.parentStatus.reason}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApprovalDialog(request, false),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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

  // Helper Widgets
  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
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
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(onPressed: onViewAll, child: const Text('View All')),
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
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
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
          children: [
            Text('Are you sure you want to ${isApproval ? 'approve' : 'reject'} this request for ${request.studentName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: isApproval ? 'Comment (Optional)' : 'Reason for rejection *',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!isApproval && commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is required.'), backgroundColor: Colors.red),
                );
                return;
              }
              _handleApproval(request, isApproval, commentController.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: isApproval ? Colors.green : Colors.red, foregroundColor: Colors.white),
            child: Text(isApproval ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _handleApproval(LeaveRequest request, bool isApproval, String comment) async {
    try {
      setState(() => _isLoading = true);
      await _wardenService.decideApplication(
        id: request.id,
        decision: isApproval ? 'approved' : 'rejected',
        rejectionReason: isApproval ? null : comment,
      );
      await _loadLeaveRequests();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApproval ? 'Leave request approved!' : 'Leave request rejected.'),
          backgroundColor: isApproval ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update leave request.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
