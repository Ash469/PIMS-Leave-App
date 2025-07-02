import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/parent_service.dart';

class ParentProfileScreen extends StatefulWidget {
  const ParentProfileScreen({super.key});

  @override
  State<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen> {
  String? _parentName;
  String? _parentEmail;
  String? _token;
  bool _loading = true;
  List<Ward> _wards = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _parentName = prefs.getString('name') ?? 'Parent';
      _parentEmail = prefs.getString('email') ?? '';
      _token = prefs.getString('token');
    });
    if (_token != null && _token!.isNotEmpty) {
      try {
        final wards = await ParentService.fetchWards(token: _token!);
        setState(() {
          _wards = wards;
          _loading = false;
        });
      } catch (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load wards')),
        );
      }
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(_parentName ?? 'Parent'),
                      subtitle: Text(_parentEmail ?? ''),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your Wards',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _wards.isEmpty
                      ? const Text('No wards found.')
                      : Expanded(
                          child: ListView.builder(
                            itemCount: _wards.length,
                            itemBuilder: (context, index) {
                              final ward = _wards[index];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.child_care, color: Colors.green),
                                  title: Text(ward.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Email: ${ward.email}'),
                                      Text('Batch: ${ward.batch}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}
