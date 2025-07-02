// screens/leave_request_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/leave_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({Key? key}) : super(key: key);

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

  // Make selectedStartDate and selectedEndDate state variables
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

  Future<void> postLeave({
    required String startDate,
    required String endDate,
    required String reason,
    File? document,
  }) async {
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
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        document: document,
      );
      // If no exception, treat as success (status 201)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request submitted!')),
      );
      _formKey.currentState?.reset();
      startDateController.clear();
      endDateController.clear();
      reasonController.clear();
      setState(() {
        pickedFile = null;
      });
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/student-dashboard',
        (route) => false,
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit leave. Please try again.')),
      );
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Leave'),
        automaticallyImplyLeading: false,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextFormField(
                      controller: startDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Start Date & Time',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedStartDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    selectedStartDate = null;
                                    startDateController.clear();
                                  });
                                },
                              ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Start date required' : null,
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedStartDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedStartDate ?? DateTime.now()),
                          );
                          DateTime finalDateTime = pickedDate;
                          if (pickedTime != null) {
                            finalDateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          }
                          setState(() {
                            selectedStartDate = finalDateTime;
                            startDateController.text =
                                "${finalDateTime.year}-${finalDateTime.month.toString().padLeft(2, '0')}-${finalDateTime.day.toString().padLeft(2, '0')} "
                                "${finalDateTime.hour.toString().padLeft(2, '0')}:${finalDateTime.minute.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: endDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'End Date & Time',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedEndDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    selectedEndDate = null;
                                    endDateController.clear();
                                  });
                                },
                              ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'End date required' : null,
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedEndDate ?? selectedStartDate ?? DateTime.now(),
                          firstDate: selectedStartDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedEndDate ?? DateTime.now()),
                          );
                          DateTime finalDateTime = pickedDate;
                          if (pickedTime != null) {
                            finalDateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          }
                          setState(() {
                            selectedEndDate = finalDateTime;
                            endDateController.text =
                                "${finalDateTime.year}-${finalDateTime.month.toString().padLeft(2, '0')}-${finalDateTime.day.toString().padLeft(2, '0')} "
                                "${finalDateTime.hour.toString().padLeft(2, '0')}:${finalDateTime.minute.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonController,
                      decoration: const InputDecoration(labelText: 'Reason'),
                      maxLines: 2,
                      validator: (value) => value == null || value.isEmpty ? 'Reason required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pickedFile != null
                                ? 'Document: ${pickedFile?.path.split('/').last}'
                                : 'No document selected',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file),
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
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState?.validate() ?? false) {
                          await postLeave(
                            startDate: startDateController.text,
                            endDate: endDateController.text,
                            reason: reasonController.text,
                            document: pickedFile,
                          );
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}