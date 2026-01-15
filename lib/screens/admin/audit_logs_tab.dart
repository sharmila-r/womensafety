import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';

class AuditLogsTab extends StatelessWidget {
  final AdminService adminService;

  const AuditLogsTab({super.key, required this.adminService});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              Icon(Icons.history, color: Color(0xFFE91E63)),
              SizedBox(width: 8),
              Text(
                'Audit Logs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Logs list
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: adminService.getAuditLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final logs = snapshot.data ?? [];

              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No audit logs yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return _buildLogItem(logs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? 'unknown';
    final adminName = log['adminName'] as String? ?? 'Unknown';
    final targetId = log['targetId'] as String? ?? '';
    final timestamp = log['timestamp'] as Timestamp?;
    final details = log['details'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getActionColor(action).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActionIcon(action),
                color: _getActionColor(action),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatAction(action),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By: $adminName',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (targetId.isNotEmpty)
                    Text(
                      'Target: ${targetId.length > 12 ? '${targetId.substring(0, 12)}...' : targetId}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: details.entries.map((e) {
                        if (e.value == null) return const SizedBox.shrink();
                        return Chip(
                          label: Text(
                            '${e.key}: ${e.value}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            // Timestamp
            if (timestamp != null)
              Text(
                _formatTimestamp(timestamp.toDate()),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'report_status_update':
        return Icons.edit;
      case 'report_forwarded':
        return Icons.forward;
      case 'volunteer_approved':
        return Icons.check_circle;
      case 'volunteer_rejected':
        return Icons.cancel;
      case 'volunteer_vouched':
        return Icons.verified;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'report_status_update':
        return Colors.blue;
      case 'report_forwarded':
        return Colors.purple;
      case 'volunteer_approved':
      case 'volunteer_vouched':
        return Colors.green;
      case 'volunteer_rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatAction(String action) {
    switch (action) {
      case 'report_status_update':
        return 'Report Status Updated';
      case 'report_forwarded':
        return 'Report Forwarded';
      case 'volunteer_approved':
        return 'Volunteer Approved';
      case 'volunteer_rejected':
        return 'Volunteer Rejected';
      case 'volunteer_vouched':
        return 'Volunteer Vouched';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
