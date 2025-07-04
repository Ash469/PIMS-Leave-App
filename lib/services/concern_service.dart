import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

class ConcernService {
  static const String baseUrl = 'https://college-leave-backend.onrender.com/api/guard';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// 1. Create a new concern
  Future<Map<String, dynamic>> createConcern({
    required String studentId,
    required String studentName,
    required String batch,
    required String description,
    File? document,
  }) async {
    dev.log('[ConcernService] POST $baseUrl/concerns');
    final url = Uri.parse('$baseUrl/concerns');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    var request = http.MultipartRequest('POST', url);
    request.fields['studentId'] = studentId;
    request.fields['studentName'] = studentName;
    request.fields['batch'] = batch;
    request.fields['description'] = description;
    request.headers['Authorization'] = 'Bearer $token';

    dev.log('[ConcernService] Fields: ${request.fields}');
    if (document != null) {
      dev.log('[ConcernService] Attaching document: ${document.path}');
      request.files.add(await http.MultipartFile.fromPath('document', document.path)); // Ensure field name is 'document'
    }

    final response = await request.send();
    dev.log('[ConcernService] Response status: ${response.statusCode}');
    final responseBody = await response.stream.bytesToString();
    dev.log('[ConcernService] Response body: $responseBody');

    if (response.statusCode == 201) {
      return {
        'message': 'Concern created successfully',
        
      };
    } else if (response.statusCode == 400) {
      try {
        final data = json.decode(responseBody);
        throw Exception(data['message']?.toString() ?? 'Bad Request: Missing required fields');
      } catch (_) {
        throw Exception('Bad Request: Missing required fields');
      }
    } else {
      try {
        final data = json.decode(responseBody);
        throw Exception(data['message']?.toString() ?? 'Failed to create concern');
      } catch (_) {
        throw Exception('Failed to create concern');
      }
    }
  }

  /// 2. Fetch all concerns
  Future<List<Map<String, dynamic>>> fetchConcerns() async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/concerns');
    dev.log('[API] GET $url');
    dev.log('[API] Headers: $headers');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data['concerns'] as List);
    } else {
      throw Exception('Failed to fetch concerns: ${res.statusCode}');
    }
  }

  /// 3. Get details of a specific concern
  Future<Map<String, dynamic>> getConcernDetails(String id) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl/concerns/$id');
    dev.log('[API] GET $url');
    dev.log('[API] Headers: $headers');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);

      return Map<String, dynamic>.from(data['concern']);
    } else {
      throw Exception('Failed to fetch concern details: ${res.statusCode}');
    }
  }

  /// 4. Fetch all students
  Future<List<Map<String, dynamic>>> fetchAllStudents({String? batch}) async {
    final headers = await _getHeaders();
    final queryParameters = batch != null ? <String, String>{'batch': batch} : <String, String>{};
    final url = Uri.parse('$baseUrl/allstudents').replace(queryParameters: queryParameters);
    dev.log('[API] GET $url');
    dev.log('[API] Headers: $headers');
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      dev.log('[API] Fetched students: ${data['students']}');
      return List<Map<String, dynamic>>.from(data['students'] as List);
    } else {
      throw Exception('Failed to fetch students: ${res.statusCode}');
    }
  }
}
