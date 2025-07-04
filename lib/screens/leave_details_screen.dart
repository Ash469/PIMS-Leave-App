import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class LeaveDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? rawJson;

  const LeaveDetailsScreen({super.key, required this.rawJson});

  @override
  State<LeaveDetailsScreen> createState() => _LeaveDetailsScreenState();
}

class _LeaveDetailsScreenState extends State<LeaveDetailsScreen> {
  String? previewUrl;
  bool loadingPreview = false;
  String? previewError;

  @override
  void initState() {
    super.initState();
    _fetchDocumentPreview();
  }

  Future<void> _fetchDocumentPreview() async {
    final rawJson = widget.rawJson;
    if (rawJson == null) return;
    final docUrl = rawJson['documentUrl']?.toString() ?? '';
    if (docUrl.isEmpty) return;
    setState(() {
      loadingPreview = true;
      previewError = null;
    });
    try {
      setState(() {
        previewUrl =
            'https://college-leave-backend.onrender.com/api/drive/$docUrl';
        loadingPreview = false;
      });
    } catch (e) {
      setState(() {
        previewError = 'Failed to load document preview.';
        loadingPreview = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawJson = widget.rawJson;
    if (rawJson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave Application Details')),
        body: const Center(child: Text('No details available.')),
      );
    }

    String getField(String key) => rawJson[key]?.toString() ?? '';

    String formatDate(String? iso) {
      if (iso == null || iso.isEmpty) return '';
      try {
        final dt = DateTime.parse(iso);
        return DateFormat('d MMM yyyy, HH:mm').format(dt);
      } catch (_) {
        return iso;
      }
    }

    Map<String, dynamic> parentStatus = rawJson['parentStatus'] ?? {};
    Map<String, dynamic> wardenStatus = rawJson['wardenStatus'] ?? {};
    Map<String, dynamic> guardStatus = rawJson['guardStatus'] ?? {};
    Map<String, dynamic> adminStatus = rawJson['adminStatus'] ?? {};

    Widget statusChip(String? status) {
      Color color;
      switch (status) {
        case 'approved':
          color = Colors.green;
          break;
        case 'rejected':
          color = Colors.red;
          break;
        case 'stopped':
          color = Colors.red;
          break;
        case 'pending':
        default:
          color = Colors.orange;
      }
      return Chip(
        label: Text(
          (status ?? 'pending').replaceFirst(status![0], status[0].toUpperCase()),
        ),
        backgroundColor: color.withOpacity(0.2),
        labelStyle: TextStyle(color: color),
      );
    }

    Widget timelineStop({
      required String title,
      required IconData icon,
      required Map<String, dynamic> statusObj,
      required bool isFirst,
      required bool isLast,
    }) {
      final status = statusObj['status']?.toString();
      final decided =
          status != null && status != 'pending' && status.isNotEmpty;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: MediaQuery.of(context).size.height * 0.05, // Responsive height
                  color: Colors.grey.shade400,
                ),
              CircleAvatar(
                backgroundColor: decided
                    ? (status == 'approved'
                        ? Colors.green
                        : status == 'rejected' || status == 'stopped'
                            ? Colors.red
                            : Colors.orange)
                    : Colors.grey.shade300,
                radius: MediaQuery.of(context).size.width * 0.05, // Responsive radius
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: MediaQuery.of(context).size.height * 0.05, // Responsive height
                  color: Colors.grey.shade400,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis, // Handle overflow
                          ),
                        ),
                        const SizedBox(width: 8),
                        statusChip(status),
                      ],
                    ),
                    if (decided &&
                        (statusObj['reason'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Reason: ${statusObj['reason']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    if (decided &&
                        (statusObj['decidedAt'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          'Decided At: ${formatDate(statusObj['decidedAt']?.toString())}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final hasDocument = getField('documentUrl').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Application Details'),
      ),
      floatingActionButton: hasDocument && previewUrl != null
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.attach_file),
              label: const Text('Open Document'),
              onPressed: () async {
                final url = Uri.parse(previewUrl!);
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(getField('reason')),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.exit_to_app, color: Colors.orange),
                      title: const Text('Going Out'),
                      subtitle: Text(formatDate(getField('startDate'))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.login, color: Colors.green),
                      title: const Text('Coming In'),
                      subtitle: Text(formatDate(getField('endDate'))),
                    ),
                  ),
                ),
              ],
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title:
                    Text('Created At: ${formatDate(getField('createdAt'))}'),
                subtitle:
                    Text('Updated At: ${formatDate(getField('updatedAt'))}'),
              ),
            ),
            const SizedBox(height: 16),
            if (hasDocument)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.picture_as_pdf, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Document Preview',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (loadingPreview)
                        const Center(child: CircularProgressIndicator())
                      else if (previewError != null)
                        Text(previewError!,
                            style: const TextStyle(color: Colors.red))
                      else if (previewUrl != null)
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              previewUrl!,
                              height: 220,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Could not load image.'),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open Document'),
                                    onPressed: () async {
                                      final url = Uri.parse(previewUrl!);
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    },
                                  ),
                                ],
                              ),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        const Text('No preview available.'),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Approval Timeline',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            timelineStop(
              title: 'Parent',
              icon: Icons.family_restroom,
              statusObj: parentStatus,
              isFirst: true,
              isLast: false,
            ),
            timelineStop(
              title: 'Warden',
              icon: Icons.security,
              statusObj: wardenStatus,
              isFirst: false,
              isLast: false,
            ),
            timelineStop(
              title: 'Guard',
              icon: Icons.shield,
              statusObj: guardStatus,
              isFirst: false,
              isLast: true,
            ),
            // Add admin status to the timeline if it is stopped
            if (adminStatus['status']?.toString() == 'stopped')
              timelineStop(
                title: 'Admin',
                icon: Icons.admin_panel_settings,
                statusObj: adminStatus,
                isFirst: false,
                isLast: false,
              ),
          ],
        ),
      ),
      );
    }
  }

