import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;

class AuthService {
  static const String baseUrl = 'https://college-leave-backend.onrender.com/api'; // <-- update this line

  Future<Map<String, dynamic>> verifyGoogleUser({required String email, required String role}) async {
    final url = Uri.parse('$baseUrl/auth/verify-google-user');
    final requestBody = {'email': email, 'role': role};
    dev.log('AuthService: Sending request body: $requestBody'); // Debug dev.log

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    dev.log('AuthService: Response status: ${response.statusCode}'); // Debug dev.log
    dev.log('AuthService: Response body: ${response.body}'); // Debug dev.log

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'verified': true, // Always true if status 200
        'token': data['token'],
        'name': data['name'] ?? '',
        'gender': data['gender'] ?? '',
        'role': data['role'] ?? '',
        'id': data['id'] ?? '',
        'email': data['email'] ?? '',
      };
    }
    return {'verified': false, 'token': null};
  }

  Future<bool> registerFcmToken({
    required String fcmToken,
    required String email,
    required String name,
    required String role,
    required String id,
    String? gender,
    String? deviceType,
    String? deviceId,
  }) async {
    final url = Uri.parse('$baseUrl/auth/fcm/register');
    final requestBody = {
      'token': fcmToken,
      'email': email,
      'name': name,
      'gender': gender,
      'userId': id,
      'role': role,
      if (deviceType != null) 'deviceType': deviceType,
      if (deviceId != null) 'deviceId': deviceId,
    };
    dev.log('Registering FCM token: $requestBody');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
    dev.log('FCM register response: ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    }
    return false;
  }

  Future<bool> deleteFcmToken({required String fcmToken}) async {
    final url = Uri.parse('$baseUrl/auth/fcm/delete');
    final requestBody = {'token': fcmToken};
    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      dev.log('Delete FCM token response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      dev.log('Error deleting FCM token: $e');
    }
    return false;
  }
}
