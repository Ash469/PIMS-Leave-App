import 'package:flutter/material.dart';
import 'dart:convert';

class QRScanResultScreen extends StatelessWidget {
  final String scanData;
  
  const QRScanResultScreen({super.key, required this.scanData});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> qrInfo;
    bool isValidQR = true;
    
    try {
      qrInfo = json.decode(scanData);
    } catch (e) {
      isValidQR = false;
      qrInfo = {'error': 'Invalid QR Code'};
    }
    
    final bool hasApprovedLeave = isValidQR && qrInfo.containsKey('leaveId') && qrInfo['status'] == 'Approved';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scan Result'),
        backgroundColor: hasApprovedLeave ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isValidQR)
              const _ErrorCard(message: 'Invalid QR Code')
            else if (!hasApprovedLeave)
              const _ErrorCard(message: 'No Approved Leave Found')
            else
              _LeaveInfoCard(qrInfo: qrInfo),
              
            const SizedBox(height: 32),
            
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasApprovedLeave ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveInfoCard extends StatelessWidget {
  final Map<String, dynamic> qrInfo;
  
  const _LeaveInfoCard({required this.qrInfo});

  @override
  Widget build(BuildContext context) {
    DateTime startDate = DateTime.parse(qrInfo['startDate']);
    DateTime endDate = DateTime.parse(qrInfo['endDate']);
    DateTime timestamp = DateTime.parse(qrInfo['timestamp']);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'APPROVED LEAVE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoRow("Student", qrInfo['studentName']),
            _buildInfoRow("Email", qrInfo['email']),
            _buildInfoRow("ID", qrInfo['studentId']),
            _buildInfoRow("Leave ID", qrInfo['leaveId']),
            _buildInfoRow("Reason", qrInfo['reason']),
            _buildInfoRow("From", "${startDate.day}/${startDate.month}/${startDate.year}"),
            _buildInfoRow("To", "${endDate.day}/${endDate.month}/${endDate.year}"),
            const Divider(),
            _buildInfoRow("Generated", "${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute}"),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
