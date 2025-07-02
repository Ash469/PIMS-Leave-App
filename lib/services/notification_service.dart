import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/data_models.dart';

class NotificationService {
  static const String _apiUrl = 'https://college-leave-backend.onrender.com/api/notifications';

  // Get all notifications for the logged-in user (requires bearer token)
  Future<List<AppNotification>> getNotifications(String token) async {
    print('[NotificationService] GET $_apiUrl');
    final response = await http.get(
      Uri.parse(_apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    print('[NotificationService] Response (${response.statusCode}): ${response.body}');
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => AppNotification.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  // Mark a notification as read (requires bearer token)
  Future<AppNotification> markNotificationRead(String notificationId, String token) async {
    final url = '$_apiUrl/$notificationId/read';
    print('[NotificationService] PATCH $url');
    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    print('[NotificationService] Response (${response.statusCode}): ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AppNotification.fromJson(data);
    } else {
      throw Exception('Failed to mark notification as read');
    }
  }

  // Delete a notification (calls backend)
  Future<void> deleteNotification(String notificationId, String token) async {
    final url = '$_apiUrl/$notificationId';
    print('[NotificationService] DELETE $url');
    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    print('[NotificationService] Response (${response.statusCode}): ${response.body}');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete notification');
    }
  }

  // Store deleted notification locally (only store the notification id)
  Future<void> storeDeletedNotification(AppNotification notification) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'deleted_notifications';
    List<String> deleted = prefs.getStringList(key) ?? [];
    if (!deleted.contains(notification.id)) {
      deleted.add(notification.id);
      await prefs.setStringList(key, deleted);
    }
  }

  // Remove notification id from deleted list (after permanent delete)
  Future<void> removeDeletedNotificationId(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'deleted_notifications';
    List<String> deleted = prefs.getStringList(key) ?? [];
    if (deleted.contains(notificationId)) {
      deleted.remove(notificationId);
      await prefs.setStringList(key, deleted);
    }
  }

  // Get all deleted notification ids for the user
  Future<List<String>> getDeletedNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'deleted_notifications';
    return prefs.getStringList(key) ?? [];
  }

  // Clear all deleted notifications from temp storage
  Future<void> clearDeletedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('deleted_notifications');
  }
}

