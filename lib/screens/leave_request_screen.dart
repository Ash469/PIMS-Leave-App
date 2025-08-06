import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/leave_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final startDateController = TextEditingController();
  final endDateController = TextEditingController();
  final reasonController = TextEditingController();
  File? pickedFile;
  bool loading = false;
  String? _token;

  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
    });
  }

  Future<void> postLeave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authenticated. Please login again.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final leaveService = LeaveService();
      await leaveService.createLeave(
        token: _token!,
        startDate: selectedStartDate!.toIso8601String(),
        endDate: selectedEndDate!.toIso8601String(),
        reason: reasonController.text,
        document: pickedFile,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit leave. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (startDateController.text.isNotEmpty ||
        endDateController.text.isNotEmpty ||
        reasonController.text.isNotEmpty ||
        pickedFile != null) {
      final shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text('Are you sure you want to leave this page? Any unsaved changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      return shouldPop ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _onWillPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('New Leave Request'),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.indigo.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildDateTimePicker(
                      context: context,
                      controller: startDateController,
                      label: 'Start Date & Time',
                      onDateSelected: (date) {
                        setState(() {
                          selectedStartDate = date;
                          startDateController.text = DateFormat('d MMM yyyy, hh:mm a').format(date);
                          // Clear end date if it's before the new start date
                          if (selectedEndDate != null && selectedEndDate!.isBefore(date)) {
                            selectedEndDate = null;
                            endDateController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDateTimePicker(
                      context: context,
                      controller: endDateController,
                      label: 'End Date & Time',
                      firstDate: selectedStartDate,
                      onDateSelected: (date) {
                        setState(() {
                          selectedEndDate = date;
                          endDateController.text = DateFormat('d MMM yyyy, hh:mm a').format(date);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Leave',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        prefixIcon: Icon(Icons.edit_note_outlined),
                      ),
                      maxLines: 3,
                      validator: (value) => value == null || value.isEmpty ? 'Reason is required' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildFilePicker(),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: postLeave,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Submit Request'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required Function(DateTime) onDateSelected,
    DateTime? firstDate,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      validator: (value) => value == null || value.isEmpty ? '$label is required' : null,
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: firstDate ?? DateTime.now(),
          firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (pickedDate != null) {
          if (!mounted) return;
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(firstDate ?? DateTime.now()),
          );
          if (pickedTime != null) {
            final finalDateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
            onDateSelected(finalDateTime);
          }
        }
      },
    );
  }

  Widget _buildFilePicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pickedFile != null ? pickedFile!.path.split('/').last : 'Attach a document (optional)',
              style: TextStyle(color: pickedFile != null ? Colors.black : Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (pickedFile != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: () {
                setState(() {
                  pickedFile = null;
                });
              },
            )
          else
            TextButton(
              child: const Text('Select'),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(type: FileType.any);
                if (result != null && result.files.single.path != null) {
                  setState(() {
                    pickedFile = File(result.files.single.path!);
                  });
                }
              },
            ),
        ],
      ),
    );
  }
}
