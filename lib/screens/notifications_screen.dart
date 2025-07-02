import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // <-- Add this import
import '../services/notification_service.dart';
import '../models/data_models.dart';

class NotificationsScreen extends StatefulWidget {
  final String? token;
  final NotificationService? notificationService;

  const NotificationsScreen({Key? key, this.token, this.notificationService}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _notificationsFuture;
  late Future<List<String>> _deletedIdsFuture;
  String? _token;
  Set<String> _selectedIds = {}; 
  late NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = widget.notificationService ?? NotificationService();
    _refreshNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshNotifications();
  }

  Future<void> _refreshNotifications() async {
    if (widget.token != null) {
      setState(() {
        _token = widget.token;
        _notificationsFuture = _notificationService.getNotifications(_token!);
        _deletedIdsFuture = _notificationService.getDeletedNotificationIds();
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    setState(() {
      _token = token;
      if (_token != null) {
        _notificationsFuture = _notificationService.getNotifications(_token!);
        _deletedIdsFuture = _notificationService.getDeletedNotificationIds();
      }
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    if (_token == null) return;
    await _notificationService.markNotificationRead(notificationId, _token!);
    _refreshNotifications();
  }

  Future<void> _deleteNotification(AppNotification n) async {
    if (_token == null) return;
    await _notificationService.storeDeletedNotification(n);
    _refreshNotifications();
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelectedNotifications(List<AppNotification> notifications) async {
    if (_token == null ) return;
    final idsToDelete = _selectedIds.toSet();
    for (final n in notifications.where((n) => idsToDelete.contains(n.id))) {
      await _notificationService.storeDeletedNotification(n);
    }
    _refreshNotifications();
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _permanentlyDeleteNotification(AppNotification n) async {
    if (_token == null) return;
    await _notificationService.deleteNotification(n.id, _token!);
    await _notificationService.removeDeletedNotificationId(n.id);
    // Remove from local notifications list in memory (to avoid reappearing until next fetch)
    final currentList = await _notificationsFuture;
    setState(() {
      _notificationsFuture = Future.value(currentList.where((item) => item.id != n.id).toList());
    });
    _refreshNotifications();
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _selectedIds.isEmpty
              ? const Text('Notifications')
              : Text('${_selectedIds.length} selected'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Inbox'),
              Tab(text: 'Deleted'),
            ],
          ),
          actions: [
            if (_selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  final notifications = await _notificationsFuture;
                  await _deleteSelectedNotifications(notifications);
                },
              ),
          ],
        ),
        body: TabBarView(
          children: [
            // Inbox Tab
            FutureBuilder<List<AppNotification>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No notifications.'));
                }
                final notifications = snapshot.data!;
                return FutureBuilder<List<String>>(
                  future: _deletedIdsFuture,
                  builder: (context, deletedSnapshot) {
                    if (deletedSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final deletedIds = deletedSnapshot.data ?? [];
                    final inboxNotifications = notifications
                        .where((n) => !deletedIds.contains(n.id))
                        .toList()
                      ..sort((a, b) {
                        final dateA = a.createdAt is DateTime
                            ? a.createdAt
                            : DateTime.tryParse(a.createdAt.toString());
                        final dateB = b.createdAt is DateTime
                            ? b.createdAt
                            : DateTime.tryParse(b.createdAt.toString());
                        return dateB?.compareTo(dateA ?? DateTime(0)) ?? 0;
                      });
                    if (inboxNotifications.isEmpty) {
                      return const Center(child: Text('No notifications.'));
                    }
                    return ListView.builder(
                      itemCount: inboxNotifications.length,
                      itemBuilder: (context, index) {
                        final n = inboxNotifications[index];

                        // Format created date
                        String createdAt = '';
                        if (n.createdAt != null) {
                          final dt = n.createdAt is DateTime
                              ? n.createdAt
                              : DateTime.tryParse(n.createdAt.toString());
                          if (dt != null) {
                            createdAt = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          }
                        }

                        // Leave details if present
                        String leaveReason = '';
                        String leaveStatus = '';
                        if (n.leave != null) {
                          if (n.leave is Map) {
                            leaveReason = n.leave['reason'] ?? '';
                            final parentStatus = n.leave['parentStatus']?['status'];
                            final wardenStatus = n.leave['wardenStatus']?['status'];
                            final guardStatus = n.leave['guardStatus']?['status'];
                            leaveStatus = [
                              if (parentStatus != null) 'Parent: $parentStatus',
                              if (wardenStatus != null) 'Warden: $wardenStatus',
                              if (guardStatus != null) 'Guard: $guardStatus',
                            ].join(' | ');
                          } else if (n.leave is String) {
                            // If leave is just an ID string, show it or skip
                            leaveReason = 'Leave ID: ${n.leave}';
                          }
                        }

                        final isSelected = _selectedIds.contains(n.id);

                        return Dismissible(
                          key: Key(n.id),
                          direction: DismissDirection.startToEnd, // swipe right to delete
                          background: Container(
                            alignment: Alignment.centerLeft,
                            color: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            // Only allow swipe if not in selection mode
                            return _selectedIds.isEmpty;
                          },
                          onDismissed: (direction) async {
                            await _deleteNotification(n);
                          },
                          child: GestureDetector(
                            onLongPress: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(n.id);
                                } else {
                                  _selectedIds.add(n.id);
                                }
                              });
                            },
                            onTap: _selectedIds.isNotEmpty
                                ? () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedIds.remove(n.id);
                                      } else {
                                        _selectedIds.add(n.id);
                                      }
                                    });
                                  }
                                : () async {
                                    if (n.read != true) {
                                      await _markAsRead(n.id);
                                    }
                                  },
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: isSelected
                                  ? Colors.blue[100]
                                  : (n.read == true ? Colors.grey[200] : Colors.blue[200]),
                              child: ListTile(
                                title: Text(
                                  n.message ?? '',
                                  style: TextStyle(
                                    fontWeight: n.read == true ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 13, // smaller font size
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (leaveReason.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          'Leave: $leaveReason',
                                          style: const TextStyle(fontSize: 11), // smaller font
                                        ),
                                      ),
                                    if (createdAt.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          createdAt,
                                          style: const TextStyle(fontSize: 10, color: Colors.grey), // smaller font
                                        ),
                                      ),
                                  ],
                                ),
                                // Removed trailing PopupMenuButton
                                selected: isSelected,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            // Deleted Tab
            FutureBuilder<List<String>>(
              future: _deletedIdsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final deletedIds = snapshot.data ?? [];
                if (deletedIds.isEmpty) {
                  return const Center(child: Text('No deleted notifications.'));
                }
                return FutureBuilder<List<AppNotification>>(
                  future: _notificationsFuture,
                  builder: (context, notifSnapshot) {
                    if (notifSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allNotifications = notifSnapshot.data ?? [];
                    final deleted = allNotifications.where((n) => deletedIds.contains(n.id)).toList();
                    if (deleted.isEmpty) {
                      return const Center(child: Text('No deleted notifications.'));
                    }
                    return ListView.builder(
                      itemCount: deleted.length,
                      itemBuilder: (context, index) {
                        final n = deleted[index];
                        String createdAt = '';
                        if (n.createdAt != null) {
                          final dt = n.createdAt is DateTime
                              ? n.createdAt
                              : DateTime.tryParse(n.createdAt.toString());
                          if (dt != null) {
                            createdAt = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          }
                        }
                        String leaveReason = '';
                        String leaveStatus = '';
                        if (n.leave != null) {
                          if (n.leave is Map) {
                            leaveReason = n.leave['reason'] ?? '';

                          } else if (n.leave is String) {
                            leaveReason = 'Leave ID: ${n.leave}';
                          }
                        }
                        return Dismissible(
                          key: Key('deleted_${n.id}'),
                          direction: DismissDirection.startToEnd,
                          background: Container(
                            alignment: Alignment.centerLeft,
                            color: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete_forever, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            // Confirm permanent delete
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Permanently?'),
                                content: const Text('This will permanently delete the notification.'),
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
                            ) ?? false;
                          },
                          onDismissed: (direction) async {
                            await _permanentlyDeleteNotification(n);
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: Colors.grey[300],
                            child: ListTile(
                              title: Text(
                                n.message ?? '',
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (leaveReason.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text('Reason: $leaveReason', style: const TextStyle(fontSize: 11)),
                                    ),
                                  if (leaveStatus.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(leaveStatus, style: const TextStyle(fontSize: 11)),
                                    ),
                                  if (createdAt.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        createdAt,
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                                tooltip: 'Delete permanently',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Permanently?'),
                                      content: const Text('This will permanently delete the notification.'),
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
                                    await _permanentlyDeleteNotification(n);
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
