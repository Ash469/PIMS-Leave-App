import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/guard_service.dart';
import 'dart:developer' as dev;

class QrScannerScreen extends StatefulWidget {
  final Function(String) onQrCodeScanned;
  final String tab; 

  const QrScannerScreen({super.key, required this.onQrCodeScanned, required this.tab});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  String? jwtToken;
  bool _hasPermission = false;
  bool _isScanning = false;
  bool _hasScanned = false;
  String? _centerMessage;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _loadJwtToken();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan QR codes.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _loadJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      jwtToken = prefs.getString('token');
    });
    dev.log('Loaded jwtToken: $jwtToken');
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _hasScanned = false;
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
      _hasScanned = true;
    });
  }

  void _showCenterMessage(String message) {
    setState(() {
      _centerMessage = message;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _centerMessage = null;
        });
      }
    });
  }

  Future<void> _handleQrCode(String qrData) async {
    if (jwtToken == null) return;
    _stopScanning();

    if (widget.tab == 'departure') {
      await _handleQrCodeForDeparture(qrData);
    } else if (widget.tab == 'return') {
      await _handleQrCodeForReturn(qrData);
    }
  }

  Future<void> _handleQrCodeForDeparture(String qrData) async {
    try {
      final data = qrData.split('|'); // Expecting "name|reason|leaveId"
      if (data.length != 3) throw Exception('Invalid QR code format');
      final leaveId = data[2].trim();
      dev.log('Extracted Leave ID: $leaveId');

      final decision = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${data[0]}'),
              Text('Reason: ${data[1]}'),
              Text('Leave ID: $leaveId'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'rejected'),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'approved'),
              child: const Text('Approve'),
            ),
          ],
        ),
      );

      if (decision != null) {
        String? rejectionReason;
        if (decision == 'rejected') {
          rejectionReason = await _showRejectionReasonDialog();
          if (rejectionReason == null || rejectionReason.trim().isEmpty) return;
        }

        final response = await GuardService.decideOnDeparture(
          jwtToken: jwtToken!,
          id: leaveId,
          decision: decision,
          rejectionReason: rejectionReason,
        );

        dev.log('Decide on Departure API Response: $response');
        _showCenterMessage('Leave $decision successfully');
      }
    } catch (e) {
      dev.log('Error in _handleQrCodeForDeparture: $e');
      if (e.toString().contains('409')) {
        _showCenterMessage('Already marked.');
      } else {
        _showCenterMessage('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _handleQrCodeForReturn(String qrData) async {
    try {
      final data = qrData.split('|'); // Expecting "name|reason|leaveId"
      if (data.length != 3) throw Exception('Invalid QR code format');
      final leaveId = data[2].trim();
      dev.log('Extracted Leave ID: $leaveId');

      final snapshot = await GuardService.getDepartedAwaitingReturn(jwtToken!);
      final leaves = snapshot['leaves'] ?? [];
      dev.log('API Response Body: $snapshot');

      final matchingLeave = leaves.firstWhere(
        (leave) => leave['_id'] == leaveId,
        orElse: () => null,
      );

      if (matchingLeave == null) {
        _showCenterMessage('No matching leave found for return.');
        return;
      }

      dev.log('Matching Leave Found: $matchingLeave');

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Return'),
          content: Text(
            'Are you sure you want to mark the return for ${matchingLeave['student']['name']}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final response = await GuardService.markStudentReturn(
          jwtToken: jwtToken!,
          id: leaveId,
        );

        dev.log('Mark Return API Response: $response');
        _showCenterMessage('Student marked as returned successfully');
      }
    } catch (e) {
      dev.log('Error in _handleQrCodeForReturn: $e');
      _showCenterMessage('Error: ${e.toString()}');
    }
  }

  Future<String?> _showRejectionReasonDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reason for Rejection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Enter reason',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Stack(
        children: [
          // Fully dark background (no camera preview)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.85),
            ),
          ),
          // Circular scan button in the center
          if (!_isScanning)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      _startScanning();
                    },
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.blueAccent, Colors.lightBlueAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_scanner, size: 48, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Click the button to start scanning.',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          // Camera preview with overlay (when scanning)
          if (_isScanning)
            Positioned.fill(
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (result) {
                      final qrData = result.barcodes.first.rawValue;
                      if (qrData != null && !_hasScanned) {
                        dev.log('Scanned QR Code: $qrData');
                        _handleQrCode(qrData);
                      }
                    },
                  ),
                  // Overlay with transparent circular scan area
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScannerOverlayPainter(),
                    ),
                  ),
                  // Move scan instruction text below the scan area
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Align QR code within the circle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Show a button to scan again after a scan
          if (_hasScanned && !_isScanning)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () {
                    _startScanning();
                  },
                ),
              ),
            ),
          // Centered message overlay
          if (_centerMessage != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _centerMessage != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _centerMessage ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom painter for circular scan overlay
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;
    final radius = width * 0.35;
    final center = Offset(width / 2, height / 2);

    // Draw dark overlay
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);


    // Draw white border for scan area
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
    // Draw dark overlay
    