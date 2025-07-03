import 'package:flutter/material.dart';
import 'package:pims_app/screens/qr_scanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/guard_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'leave_details_screen.dart';
import 'package:flutter/services.dart'; // Add this import
import 'notifications_screen.dart'; // <-- Add this import
import 'package:url_launcher/url_launcher.dart'; // <-- Add this import
import '../services/concern_service.dart'; // Add this import
import 'raise_concern_screen.dart'; // Add this import
import 'package:file_picker/file_picker.dart'; // <-- Add this import

class GuardDashboardScreen extends StatefulWidget {
  const GuardDashboardScreen({super.key});

  @override
  State<GuardDashboardScreen> createState() => _GuardDashboardScreenState();
}

class _GuardDashboardScreenState extends State<GuardDashboardScreen> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _departedAwaitingReturnFuture;
  late Future<Map<String, dynamic>> _allDepartureFuture;
  String? jwtToken;
  late TabController _tabController;
  String _filter = 'All'; // All, Pending, Approved, Rejected
  DateTime? _lastBackPressed; // Add this field
  final ConcernService _concernService = ConcernService(); // Add ConcernService instance

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTokenAndRefresh();
  }

  Future<void> _loadTokenAndRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    setState(() {
      jwtToken = token;
      if (jwtToken != null) {
        print('Loaded jwtToken: $jwtToken'); // Debugging log
        _departedAwaitingReturnFuture =
            GuardService.getDepartedAwaitingReturn(jwtToken!);
        _allDepartureFuture =
            GuardService.getPendingDepartureApplications(jwtToken!);
      } else {
        print('JWT token is null. Please log in again.'); // Debugging log
      }
    });
  }

  void _refreshData() {
    if (jwtToken != null) {
      setState(() {
        _departedAwaitingReturnFuture =
            GuardService.getDepartedAwaitingReturn(jwtToken!);
        _allDepartureFuture =
            GuardService.getPendingDepartureApplications(jwtToken!);
      });
    }
  }

  Future<void> _handleDecision(String id, String decision) async {
    if (jwtToken == null) return;
    String? reason;
    if (decision == 'rejected') {
      reason = await _showRejectionReasonDialog();
      if (reason == null || reason.trim().isEmpty) return;
    }
    await GuardService.decideOnDeparture(
      jwtToken: jwtToken!,
      id: id,
      decision: decision,
      rejectionReason: reason,
    );
    _refreshData();
  }

  Future<String?> _showRejectionReasonDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for Rejection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Enter reason',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // Replace _showApplicationDetails with navigation to LeaveDetailsScreen
  Future<void> _showApplicationDetails(String id) async {
    if (jwtToken == null) return;
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final details = await GuardService.getLeaveApplicationById(jwtToken!, id);
      if (!mounted) return;
      Navigator.pop(context); // Remove loading dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LeaveDetailsScreen(
            rawJson: details['leave'] ?? details, // Use 'leave' key if present
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading dialog if present
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch application details: $e')),
        );
      }
    }
  }

  Future<void> _handleMarkReturn(String id) async {
    if (jwtToken == null) return;
    await GuardService.markStudentReturn(
      jwtToken: jwtToken!,
      id: id,
    );
    _refreshData();
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
             "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _handleQrCodeForDeparture(String qrData) async {
    if (jwtToken == null) return;
    try {
      final data = qrData.split('|'); // Expecting "name|reason|leaveId"
      if (data.length != 3) throw Exception('Invalid QR code format');
      final leaveId = data[2];

      final decision = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${data[0]}'),
              Text('Reason: ${data[1]}'),
              Text('Leave ID: $leaveId'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'rejected'),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'approved'),
              child: const Text('Approve'),
            ),
          ],
        ),
      );

      if (decision != null) {
        String? rejectionReason;
        if (decision == 'rejected') {
          rejectionReason = await _showRejectionReasonDialog();
          if (rejectionReason == null || rejectionReason.trim().isEmpty) return;
        }

        await GuardService.decideOnDeparture(
          jwtToken: jwtToken!,
          id: leaveId,
          decision: decision,
          rejectionReason: rejectionReason,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave $decision successfully')),
        );
        _refreshData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleQrCodeForReturn(String qrData) async {
    if (jwtToken == null) return;
    try {
      final leaveId = qrData.trim(); // Expecting only the leave ID in QR code
      final snapshot = await _departedAwaitingReturnFuture;
      final leaves = snapshot['leaves'] ?? [];
      final matchingLeave = leaves.firstWhere(
        (leave) => leave['_id'] == leaveId,
        orElse: () => null,
      );

      if (matchingLeave == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching leave found for return.')),
        );
        return;
      }

      await GuardService.markStudentReturn(
        jwtToken: jwtToken!,
        id: leaveId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student marked as returned successfully')),
      );
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Widget _buildQrScannerButton(Function(String) onQrCodeScanned, {required String tab}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QrScannerScreen(
              onQrCodeScanned: onQrCodeScanned,
              tab: tab,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Text(
              'Scan QR Code',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (jwtToken == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
        appBar: AppBar(
          title: const Text('Guard Dashboard'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false, // <-- Remove default back button
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
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
                  await prefs.remove('user_email');
                  await prefs.setBool('isLoggedIn', false);
                  await prefs.remove('token');
                  await prefs.remove('role');
                  await prefs.remove('email');
                  await prefs.remove('student_name');
                  try {
                    await GoogleSignIn().signOut();
                  } catch (_) {}
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/role-selection',
                      (route) => false,
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
            ),
            IconButton(
              icon: const Icon(Icons.add_alert),
              tooltip: 'Raise Concern',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RaiseConcernScreen()),
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Departure'),
              Tab(text: 'Return'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Departure Tab
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildQrScannerButton(_handleQrCodeForDeparture, tab: 'departure'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _allDepartureFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (snapshot.hasData) {
                          final leaves = snapshot.data!['leaves'] ?? [];
                          // Filtering and sorting directly on the response
                          List<dynamic> filtered = leaves;
                          if (_filter != 'All') {
                            filtered = leaves.where((app) => (app['guardStatus']?['status'] ?? 'pending') == _filter.toLowerCase()).toList();
                          }
                          filtered.sort((a, b) {
                            String aStatus = (a['guardStatus']?['status'] ?? 'pending');
                            String bStatus = (b['guardStatus']?['status'] ?? 'pending');
                            if (aStatus == 'pending' && bStatus != 'pending') return -1;
                            if (aStatus != 'pending' && bStatus == 'pending') return 1;
                            return 0;
                          });

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Applications',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.filter_list),
                                    onSelected: (value) {
                                      setState(() {
                                        _filter = value;
                                      });
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'All', child: Text('All')),
                                      const PopupMenuItem(value: 'Pending', child: Text('Pending')),
                                      const PopupMenuItem(value: 'Approved', child: Text('Approved')),
                                      const PopupMenuItem(value: 'Rejected', child: Text('Rejected')),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: filtered.isEmpty
                                    ? const Center(child: Text('No applications found.'))
                                    : ListView.builder(
                                        itemCount: filtered.length,
                                        itemBuilder: (context, idx) {
                                          final app = filtered[idx];
                                          final status = (app['guardStatus']?['status'] ?? 'pending') as String;
                                          final statusColor = status == 'approved'
                                              ? Colors.green
                                              : status == 'rejected'
                                                  ? Colors.red
                                                  : Colors.orange;
                                          // Card UI with limited width and better design
                                          return Center(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 420),
                                              child: Card(
                                                elevation: 4,
                                                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  side: BorderSide(color: statusColor.withOpacity(0.3), width: 1.2),
                                                ),
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(16),
                                                  onTap: () => _showApplicationDetails(app['_id']),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            CircleAvatar(
                                                              backgroundColor: Colors.purple.shade100,
                                                              child: Icon(Icons.person, color: Colors.purple.shade700),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              child: Text(
                                                                app['student']?['name'] ?? 'Unknown',
                                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                              ),
                                                            ),
                                                            Chip(
                                                              label: Text(
                                                                status[0].toUpperCase() + status.substring(1),
                                                                style: TextStyle(
                                                                  color: statusColor,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                              backgroundColor: statusColor.withOpacity(0.15),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                                                            const SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                app['reason'] ?? '-',
                                                                style: const TextStyle(fontSize: 14),
                                                                maxLines: 2,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'From: ${app['startDate']?.substring(0, 10) ?? '-'}',
                                                              style: const TextStyle(fontSize: 13),
                                                            ),
                                                            const SizedBox(width: 10),
                                                            const Icon(Icons.arrow_forward, size: 16, color: Colors.blueGrey),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'To: ${app['endDate']?.substring(0, 10) ?? '-'}',
                                                              style: const TextStyle(fontSize: 13),
                                                            ),
                                                          ],
                                                        ),
                                                        if (app['documentUrl'] != null)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 6),
                                                            child: Row(
                                                              children: [
                                                                const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                                                                const SizedBox(width: 4),
                                                                Flexible(
                                                                  child: Text(
                                                                    app['documentUrl'],
                                                                    style: const TextStyle(
                                                                      color: Colors.blue,
                                                                      decoration: TextDecoration.underline,
                                                                      fontSize: 12,
                                                                    ),
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                                IconButton(
                                                                  icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                                                                  tooltip: 'Preview Document',
                                                                  onPressed: () async {
                                                                    final url = app['documentUrl'];
                                                                    if (url != null && await canLaunchUrl(Uri.parse(url))) {
                                                                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                                                    } else {
                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                        const SnackBar(content: Text('Could not open document')),
                                                                      );
                                                                    }
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        const SizedBox(height: 10),
                                                        // Only show approve/reject icons for pending, on left/right
                                                        // Only show approve/reject or admin stopped for pending status
                                                        if (status == 'pending')
                                                          (() {
                                                            final adminStatus = app['adminStatus']?['status'] ?? '';
                                                            if (adminStatus == 'stopped') {
                                                              return Row(
                                                                children: [
                                                                  const Icon(Icons.block, color: Colors.red, size: 16),
                                                                  const SizedBox(width: 4),
                                                                  const Text(
                                                                    'Admin Stopped',
                                                                    style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold),
                                                                  ),
                                                                ],
                                                              );
                                                            } else {
                                                              return Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Container(
                                                                    decoration: BoxDecoration(
                                                                      borderRadius: BorderRadius.circular(12),
                                                                      gradient: LinearGradient(
                                                                        colors: [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.5)],
                                                                        begin: Alignment.topLeft,
                                                                        end: Alignment.bottomRight,
                                                                      ),
                                                                      border: Border.all(color: Colors.green.withOpacity(0.4), width: 1),
                                                                    ),
                                                                    child: ElevatedButton(
                                                                      onPressed: () async {
                                                                        final confirm = await showDialog<bool>(
                                                                          context: context,
                                                                          builder: (context) => AlertDialog(
                                                                            title: const Text('Approve Application'),
                                                                            content: const Text('Are you sure you want to approve this application?'),
                                                                            actions: [
                                                                              TextButton(
                                                                                onPressed: () => Navigator.pop(context, false),
                                                                                child: const Text('Cancel'),
                                                                              ),
                                                                              ElevatedButton(
                                                                                onPressed: () => Navigator.pop(context, true),
                                                                                child: const Text('Approve'),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        );
                                                                        if (confirm == true) {
                                                                          await _handleDecision(app['_id'], 'approved');
                                                                        }
                                                                      },
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor: Colors.transparent,
                                                                        shadowColor: Colors.transparent,
                                                                        foregroundColor: Colors.green,
                                                                      ),
                                                                      child: const Text('Approve'),
                                                                    ),
                                                                  ),
                                                                  Container(
                                                                    decoration: BoxDecoration(
                                                                      borderRadius: BorderRadius.circular(12),
                                                                      gradient: LinearGradient(
                                                                        colors: [Colors.red.withOpacity(0.2), Colors.red.withOpacity(0.5)],
                                                                        begin: Alignment.topLeft,
                                                                        end: Alignment.bottomRight,
                                                                      ),
                                                                      border: Border.all(color: Colors.red.withOpacity(0.4), width: 1),
                                                                    ),
                                                                    child: ElevatedButton(
                                                                      onPressed: () async {
                                                                        final confirm = await showDialog<bool>(
                                                                          context: context,
                                                                          builder: (context) => AlertDialog(
                                                                            title: const Text('Reject Application'),
                                                                            content: const Text('Are you sure you want to reject this application?'),
                                                                            actions: [
                                                                              TextButton(
                                                                                onPressed: () => Navigator.pop(context, false),
                                                                                child: const Text('Cancel'),
                                                                              ),
                                                                              ElevatedButton(
                                                                                onPressed: () => Navigator.pop(context, true),
                                                                                child: const Text('Reject'),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        );
                                                                        if (confirm == true) {
                                                                          await _handleDecision(app['_id'], 'rejected');
                                                                        }
                                                                      },
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor: Colors.transparent,
                                                                        shadowColor: Colors.transparent,
                                                                        foregroundColor: Colors.red,
                                                                      ),
                                                                      child: const Text('Reject'),
                                                                    ),
                                                                  ),
                                                                ],
                                                              );
                                                            }
                                                          })(),
                                                        if (status == 'rejected' && app['guardStatus']?['reason'] != null)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 4),
                                                            child: Row(
                                                              children: [
                                                                const Icon(Icons.info, color: Colors.red, size: 16),
                                                                const SizedBox(width: 4),
                                                                Expanded(
                                                                  child: Text(
                                                                    app['guardStatus']?['reason'] ?? '',
                                                                    style: const TextStyle(fontSize: 12, color: Colors.red),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            );
                                          },
                                        ),
                                      ),
                              
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Return Tab
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildQrScannerButton(_handleQrCodeForReturn, tab: 'return'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _departedAwaitingReturnFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (snapshot.hasData) {
                          final leaves = snapshot.data!['leaves'] ?? [];
                          if (leaves.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No students awaiting return.'),
                            );
                          }
                          return ListView(
                            children: [
                              const Text(
                                'Departed Students Awaiting Return',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...leaves.map((leave) => Card(
                                child: ListTile(
                                  title: Text(leave['student']?['name'] ?? 'Unknown'),
                                  subtitle: Text(
                                    'Left at: ${_formatDateTime(leave['guardStatus']?['decidedAt'])}'
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => _handleMarkReturn(leave['_id'].toString()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Mark Returned'),
                                  ),
                                  onTap: () => _showApplicationDetails(leave['_id']),
                                ),
                              )),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
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