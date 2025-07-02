import 'dart:convert';
import 'package:http/http.dart' as http;

class GuardService {
  static const String baseUrl = 'https://college-leave-backend.onrender.com/api/guard';

  // 1. List Departed Students Awaiting Return
  static Future<Map<String, dynamic>> getDepartedAwaitingReturn(String jwtToken) async {
    final url = Uri.parse('$baseUrl/applications/departed-awaiting-return');
    print('GET $url');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );
    print('Response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      return json.decode(response.body);
      print('GuardService: Fetched departed students: ${response.body}');
    } else {
      throw Exception('Failed to fetch departed students: ${response.statusCode}');
    }
  }

  // 2. List Warden-Approved Leave Applications (Pending Guard Decision)
  // Now returns the raw response as Map<String, dynamic> (with 'leaves' key).
  static Future<Map<String, dynamic>> getPendingDepartureApplications(String jwtToken) async {
    final url = Uri.parse('$baseUrl/applications');
    print('GET $url');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );
    print('Response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch pending departures: ${response.statusCode}');
    }
  }

  // 3. Get Full Details of a Specific Leave Application
  static Future<Map<String, dynamic>> getLeaveApplicationById(String jwtToken, String id) async {
    final url = Uri.parse('$baseUrl/applications/$id');
    print('GET $url');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );
    print('Response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch leave application: ${response.statusCode}');
    }
  }

  // 4. Decide on Student Departure (Approve/Reject at Gate)
  static Future<Map<String, dynamic>> decideOnDeparture({
    required String jwtToken,
    required String id,
    required String decision, // "approved" or "rejected"
    String? rejectionReason,
  }) async {
    if (decision == 'rejected' && (rejectionReason == null || rejectionReason.trim().isEmpty)) {
      throw Exception('Rejection reason is required when rejecting an application.');
    }
    final url = Uri.parse('$baseUrl/applications/$id');
    final body = {
      'decision': decision,
      if (decision == 'rejected') 'rejectionReason': rejectionReason,
    };
    print('PATCH $url');
    print('Request Body: $body');
    final response = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );
    print('Response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to decide on departure: ${response.statusCode}');
    }
  }

  // 5. Mark Student Return
  static Future<Map<String, dynamic>> markStudentReturn({
    required String jwtToken,
    required String id,
  }) async {
    final url = Uri.parse('$baseUrl/applications/$id/return');
    print('PATCH $url');
    final response = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );
    print('Response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to mark student return: ${response.statusCode}');
    }
  }
}
