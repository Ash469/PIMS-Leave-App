import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/data_models.dart';

const String parentApiUrl = 'https://college-leave-backend.onrender.com/api/parent/applications';
const String parentWardsApiUrl = 'https://college-leave-backend.onrender.com/api/parent/ward';
const String parentDecisionApiUrl = 'https://college-leave-backend.onrender.com/api/parent/decision/json';
const String parentConcernsApiUrl = 'https://college-leave-backend.onrender.com/api/parent/concerns';

class ParentService {
  static Future<List<LeaveRequest>> fetchApplications({required String token}) async {
    print('[ParentService] GET $parentApiUrl');
    print('[ParentService] Headers: {Authorization: Bearer $token, Content-Type: application/json}');
    final response = await http.get(
      Uri.parse(parentApiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    print('[ParentService] Response status: ${response.statusCode}');
    print('[ParentService] Response body: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final leaves = data['leaves'] as List;
      return leaves.map((json) => LeaveRequest.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load applications');
    }
  }

  static Future<List<Ward>> fetchWards({required String token}) async {
    print('[ParentService] GET $parentWardsApiUrl');
    final response = await http.get(
      Uri.parse(parentWardsApiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    print('[ParentService] Response status: ${response.statusCode}');
    print('[ParentService] Response body: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final wards = data['wards'] as List;
      return wards.map((json) => Ward.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load wards');
    }
  }

  static Future<void> sendParentDecision({
    required String parentToken,
    required String decision,
    required String token,
  }) async {
    print('[ParentService] POST $parentDecisionApiUrl');
    print('[ParentService] Body: {token: $parentToken, decision: $decision}');
    final response = await http.post(
      Uri.parse(parentDecisionApiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'token': parentToken,
        'decision': decision,
      }),
    );
    print('[ParentService] Response status: ${response.statusCode}');
    print('[ParentService] Response body: ${response.body}');
    if (response.statusCode != 200) {
      throw Exception('Failed to send parent decision');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchWardConcerns({required String token}) async {
    print('[ParentService] GET $parentConcernsApiUrl');
    final response = await http.get(
      Uri.parse(parentConcernsApiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    print('[ParentService] Response status: ${response.statusCode}');
    print('[ParentService] Response body: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['concerns']);
    } else {
      throw Exception('Failed to load ward concerns');
    }
  }
}

class Ward {
  final String id;
  final String name;
  final String email;
  final int batch;

  Ward({
    required this.id,
    required this.name,
    required this.email,
    required this.batch,
  });

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      id: json['_id'],
      name: json['name'],
      email: json['email'],
      batch: json['batch'],
    );
  }
}
