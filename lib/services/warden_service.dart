import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

class WardenService {
  final String baseUrl;

  WardenService({required this.baseUrl});

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// 1. List Pending Leave Applications
  Future<List<Map<String, dynamic>>> getPendingApplications() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/warden/applications');
    dev.log('[API] GET $url');
    dev.log('[API] Headers: $headers');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data['leaves']);
    } else {
      throw Exception('Failed to fetch pending applications: ${res.statusCode}');
    }
  }

  /// 2. Get Full Details of a Specific Leave Application
  /// Uses /api/applications/:id endpoint to fetch all details including student and parent info.
  Future<Map<String, dynamic>> getApplicationDetails(String id) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/warden/applications/$id'); // <-- changed endpoint
    dev.log('[API] GET $url');
    dev.log('[API] Headers: $headers');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      dev.log('[API] Application details: ${data['leave']}');
      return Map<String, dynamic>.from(data['leave']);
    } else {
      throw Exception('Failed to fetch application details: ${res.statusCode}');
    }
  }

  /// 3. Approve or Reject a Pending Leave Application
  Future<Map<String, dynamic>> decideApplication({
    required String id,
    required String decision, // "approved" or "rejected"
    String? rejectionReason,
  }) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/warden/applications/$id');
    final body = {
      'decision': decision,
      if (decision == 'rejected' && rejectionReason != null)
        'rejectionReason': rejectionReason,
    };
    dev.log('[API] PATCH $url');
    dev.log('[API] Headers: $headers');
    dev.log('[API] Body: ${json.encode(body)}');
    final res = await http.patch(url, headers: headers, body: json.encode(body));

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return Map<String, dynamic>.from(data['leave']);
    } else {
      throw Exception('Failed to update application: ${res.statusCode}');
    }
  }
}
