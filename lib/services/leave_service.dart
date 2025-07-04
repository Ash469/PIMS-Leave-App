import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/data_models.dart';
import 'dart:developer' as dev;

const String leaveApiUrl = 'https://college-leave-backend.onrender.com/api/leave';

class LeaveService {
  // Fetch all leave requests (with token)
  Future<List<LeaveRequest>> fetchAllLeaves({required String token}) async {
    final response = await http.get(
      Uri.parse(leaveApiUrl),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    
    dev.log('[LeaveService] Response status: ${response.statusCode}');
    dev.log('[LeaveService] Response body: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Map documentUrl to attachmentPath if needed
      return List<LeaveRequest>.from(
        (data['leaves'] as List).map((leave) {
          // If your LeaveRequest.fromJson expects 'attachmentPath', but API gives 'documentUrl'
          if (leave['documentUrl'] != null) {
            leave['attachmentPath'] = leave['documentUrl'];
          }
          return LeaveRequest.fromJson(leave);
        }),
      );
    } else {
      throw Exception('Failed to fetch leaves');
    }
  }

  // Create a new leave request (with token and optional document)
  Future<LeaveRequest?> createLeave({
    required String token,
    required String startDate,
    required String endDate,
    required String reason,
    File? document,
  }) async {
    dev.log('[LeaveService] POST $leaveApiUrl');
    var request = http.MultipartRequest('POST', Uri.parse(leaveApiUrl));
    request.fields['startDate'] = startDate;
    request.fields['endDate'] = endDate;
    request.fields['reason'] = reason;
    request.headers['Authorization'] = 'Bearer $token';
    // Do NOT set Content-Type for multipart/form-data, http package handles it
    dev.log('[LeaveService] Fields: ${request.fields}');
    if (document != null) {
      dev.log('[LeaveService] Attaching document: ${document.path}');
      request.files.add(await http.MultipartFile.fromPath('document', document.path));
    }
    final response = await request.send();
    dev.log('[LeaveService] Response status: ${response.statusCode}');
    final respStr = await response.stream.bytesToString();
    dev.log('[LeaveService] Response body: $respStr');
    if (response.statusCode == 201) {
      // Option 1: Just return null, don't parse
      return null;
      // Option 2: If you want to parse, catch errors:
      /*
      try {
        final data = json.decode(respStr);
        if (data is Map && data.containsKey('leave')) {
          return LeaveRequest.fromJson(data['leave']);
        }
      } catch (e) {
        dev.log('Warning: Could not parse leave response: $e');
      }
      return null;
      */
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Invalid or expired token');
    } else if (response.statusCode == 400) {
      // Try to parse error message if possible
      try {
        final data = json.decode(respStr);
        // Always throw a string message
        throw Exception(data['message']?.toString() ?? 'Bad Request: Missing required fields');
      } catch (_) {
        throw Exception('Bad Request: Missing required fields');
      }
    } else {
      // Try to parse error message if possible
      try {
        final data = json.decode(respStr);
        throw Exception(data['message']?.toString() ?? 'Failed to create leave');
      } catch (_) {
        throw Exception('Failed to create leave');
      }
    }
  }

  // Fetch details of a specific leave by ID (with token) and return raw map for debug
  Future<Map<String, dynamic>> fetchLeaveById({
    required String token,
    required String leaveId,
  }) async {
    final url = '$leaveApiUrl/$leaveId';
    dev.log('[LeaveService] GET $url');
    dev.log('[LeaveService] Headers: {Authorization: Bearer $token, Content-Type: application/json}');
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    dev.log('[LeaveService] Response status: ${response.statusCode}');
    dev.log('[LeaveService] Response body: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else {
      throw Exception('Failed to fetch leave details');
    }
  }
}