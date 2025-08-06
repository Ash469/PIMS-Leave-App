import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../models/data_models.dart';

// New screen dedicated to showing deleted notifications
class DeletedNotificationsScreen extends StatefulWidget {
  final String token;
  final NotificationService notificationService;

  const DeletedNotificationsScreen({
    super.key,
    required this.token,
    required this.notificationService,
  });

  @override
  State<DeletedNotificationsScreen> createState() => _DeletedNotificationsScreenState();
}

class _DeletedNotificationsScreenState extends State<DeletedNotificationsScreen> {
  late Future<List<AppNotification>> _deletedNotificationsFuture;

  @override
  void initState() {
    super.initState();
    _refreshDeletedNotifications();
  }

  Future<void> _refreshDeletedNotifications() async {
    setState(() {
      _deletedNotificationsFuture = _fetchDeletedNotifications();
    });
  }

  Future<List<AppNotification>> _fetchDeletedNotifications() async {
    final allNotifications = await widget.notificationService.getNotifications(widget.token);
    final deletedIds = await widget.notificationService.getDeletedNotificationIds();
    return allNotifications.where((n) => deletedIds.contains(n.id)).toList();
  }

  Future<void> _permanentlyDeleteNotification(AppNotification n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.notificationService.deleteNotification(n.id, widget.token);
      await widget.notificationService.removeDeletedNotificationId(n.id);
      _refreshDeletedNotifications(); // Refresh the list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted Items'),
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _deletedNotificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_sweep_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No deleted notifications.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }
          final deletedNotifications = snapshot.data!;
          return ListView.builder(
            itemCount: deletedNotifications.length,
            itemBuilder: (context, index) {
              final n = deletedNotifications[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                child: ListTile(
                  title: Text(n.message ?? 'No message content'),
                  subtitle: Text('Deleted on: ${n.createdAt.toString().substring(0, 10)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () => _permanentlyDeleteNotification(n),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class NotificationsScreen extends StatefulWidget {
  final String? token;
  final NotificationService? notificationService;

  const NotificationsScreen({super.key, this.token, this.notificationService});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _notificationsFuture;
  String? _token;
  final Set<String> _selectedIds = {};
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = widget.notificationService ?? NotificationService();
    _initializeAndRefresh();
  }

  Future<void> _initializeAndRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final token = widget.token ?? prefs.getString('token');
    if (token != null) {
      setState(() {
        _token = token;
        _refreshNotifications();
      });
    }
  }

  Future<void> _refreshNotifications() async {
    if (_token == null) return;
    setState(() {
      _notificationsFuture = _fetchInboxNotifications();
      _selectedIds.clear();
    });
  }

  Future<List<AppNotification>> _fetchInboxNotifications() async {
    final allNotifications = await _notificationService.getNotifications(_token!);
    final deletedIds = await _notificationService.getDeletedNotificationIds();
    final inbox = allNotifications.where((n) => !deletedIds.contains(n.id)).toList();
    inbox.sort((a, b) => (b.createdAt as DateTime).compareTo(a.createdAt as DateTime));
    return inbox;
  }

  Future<void> _markAsRead(String notificationId) async {
    if (_token == null) return;
    await _notificationService.markNotificationRead(notificationId, _token!);
    _refreshNotifications();
  }

  Future<void> _deleteSelectedNotifications() async {
    if (_token == null || _selectedIds.isEmpty) return;
    
    final notifications = await _notificationsFuture;
    final toDelete = notifications.where((n) => _selectedIds.contains(n.id));

    for (final n in toDelete) {
      await _notificationService.storeDeletedNotification(n);
    }
    _refreshNotifications();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: _selectedIds.isEmpty
            ? const Text('Notifications')
            : Text('${_selectedIds.length} selected'),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Selected',
              onPressed: _deleteSelectedNotifications,
            ),
          if (_selectedIds.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'View Deleted Items',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DeletedNotificationsScreen(
                      token: _token!,
                      notificationService: _notificationService,
                    ),
                  ),
                ).then((_) => _refreshNotifications()); // Refresh when returning
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: FutureBuilder<List<AppNotification>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Your inbox is empty.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              );
            }
            final notifications = snapshot.data!;
            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                final isSelected = _selectedIds.contains(n.id);
                final isRead = n.read == true;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: isSelected ? Colors.blue.shade100.withOpacity(0.5) : Colors.white,
                  child: ListTile(
                    onTap: () {
                      if (_selectedIds.isNotEmpty) {
                        _toggleSelection(n.id);
                      } else if (!isRead) {
                        _markAsRead(n.id);
                      }
                    },
                    onLongPress: () {
                      _toggleSelection(n.id);
                    },
                    leading: CircleAvatar(
                      backgroundColor: isRead ? Colors.grey.shade300 : Theme.of(context).primaryColor,
                      child: Icon(
                        isRead ? Icons.done : Icons.notifications,
                        color: isRead ? Colors.grey.shade700 : Colors.white,
                      ),
                    ),
                    title: Text(
                      n.message ?? 'No message',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${(n.createdAt as DateTime).day}/${(n.createdAt as DateTime).month}/${(n.createdAt as DateTime).year}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    selected: isSelected,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
