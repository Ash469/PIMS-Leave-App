import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/concern_service.dart';

class RaiseConcernScreen extends StatefulWidget {
  const RaiseConcernScreen({Key? key}) : super(key: key);

  @override
  State<RaiseConcernScreen> createState() => _RaiseConcernScreenState();
}

class _RaiseConcernScreenState extends State<RaiseConcernScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  File? _pickedFile;
  List<Map<String, dynamic>> _allStudents = [];
  List<String> _batches = [];
  List<Map<String, dynamic>> _studentsInBatch = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  Map<String, dynamic>? _selectedStudent;
  String? _selectedBatch;
  bool _loading = false;

  final ConcernService _concernService = ConcernService();

  @override
  void initState() {
    super.initState();
    _loadAllStudents();
  }

  Future<void> _loadAllStudents() async {
    setState(() {
      _loading = true;
      _allStudents = [];
      _batches = [];
      _studentsInBatch = [];
      _filteredStudents = [];
      _selectedStudent = null;
      _selectedBatch = null;
      _batchController.clear();
      _studentNameController.clear();
    });
    try {
      final students = await _concernService.fetchAllStudents();
      final batches = students
          .map((s) => s['batch']?.toString() ?? '')
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList();
      setState(() {
        _allStudents = students;
        _batches = batches;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
    }
    setState(() => _loading = false);
  }

  void _onBatchSelected(String? batch) {
    setState(() {
      _selectedBatch = batch;
      _batchController.text = batch ?? '';
      // Fix: compare batch as string, trim spaces, and case-insensitive
      _studentsInBatch = _allStudents.where((s) =>
        (s['batch']?.toString().trim().toLowerCase() ?? '') ==
        (batch?.trim().toLowerCase() ?? '')
      ).toList();
      _filteredStudents = _studentsInBatch;
      _studentNameController.clear();
      _selectedStudent = null;
    });
    // Debug: print students in batch
    print('[DEBUG] Students in batch "$batch": $_studentsInBatch');
  }


  Future<void> _submitConcern() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student.')),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description required')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final studentId = _selectedStudent!['_id'].toString();
      final studentName = (_selectedStudent?['name'] ?? '').toString();
      final batch = (_selectedStudent?['batch'] ?? '').toString();
      final description = _descriptionController.text.trim();
      final document = _pickedFile;

      print('[DEBUG] Data: studentName=$studentName, batch=$batch, description=$description, document=${document?.path}');

      await _concernService.createConcern(
        studentId: studentId,
        studentName: studentName,
        batch: batch,
        description: description,
        document: document,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Concern raised successfully!')),
      );

      _formKey.currentState?.reset();
      setState(() {
        _pickedFile = null;
        _selectedStudent = null;
        _studentNameController.clear();
        _descriptionController.clear();
      });

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/guard-dashboard',
        (route) => false,
      );
    } catch (e) {
      print('[DEBUG] Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error raising concern: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _batchController.dispose();
    _descriptionController.dispose();
    _studentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raise Concern'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Raise a Concern',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedBatch,
                      items: _batches
                          .map((batch) => DropdownMenuItem(
                                value: batch,
                                child: Text(batch),
                              ))
                          .toList(),
                      onChanged: (batch) {
                        _onBatchSelected(batch);
                      },
                      decoration: InputDecoration(
                        labelText: 'Batch',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedBatch == null)
                      const Text(
                        'Select a batch to see students',
                        style: TextStyle(color: Colors.grey),
                      )
                    else ...[
                      TextFormField(
                        controller: _studentNameController,
                        decoration: InputDecoration(
                          labelText: 'Search Student Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          final query = value.trim().toLowerCase();
                          setState(() {
                            _filteredStudents = _studentsInBatch.where((student) {
                              final studentName = (student['name'] ?? '').toLowerCase();
                              return query.isEmpty || studentName.contains(query);
                            }).toList();
                            _selectedStudent = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _filteredStudents.isEmpty
                          ? const Center(child: Text('No students found'))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];
                                final isSelected = _selectedStudent == student;
                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: isSelected ? 4 : 1,
                                  child: ListTile(
                                    title: Text(student['name'] ?? 'Unknown'),
                                    selected: isSelected,
                                    onTap: () {
                                      setState(() {
                                        _selectedStudent = student;
                                        _studentNameController.text = student['name'] ?? '';
                                      });
                                    },
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ],
                    if (_selectedStudent != null) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Description required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _pickedFile != null
                                  ? 'Document: ${_pickedFile!.path.split('/').last}'
                                  : 'No document selected',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.attach_file),
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(type: FileType.image);
                              if (result != null && result.files.single.path != null) {
                                setState(() {
                                  _pickedFile = File(result.files.single.path!);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _submitConcern,
                          icon: const Icon(Icons.send),
                          label: const Text('Raise Concern'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
