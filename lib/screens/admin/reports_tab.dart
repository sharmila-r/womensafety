import 'package:flutter/material.dart';
import '../../models/harassment_report.dart';
import '../../services/admin_service.dart';

class ReportsTab extends StatefulWidget {
  final AdminService adminService;
  final AdminUser admin;

  const ReportsTab({
    super.key,
    required this.adminService,
    required this.admin,
  });

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  ReportReviewStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterStatus == null,
                  onSelected: (selected) {
                    setState(() => _filterStatus = null);
                  },
                  selectedColor: const Color(0xFFE91E63).withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                ...ReportReviewStatus.values.map((status) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_formatStatus(status)),
                        selected: _filterStatus == status,
                        onSelected: (selected) {
                          setState(() => _filterStatus = selected ? status : null);
                        },
                        selectedColor: _getStatusColor(status).withOpacity(0.2),
                      ),
                    )),
              ],
            ),
          ),
        ),
        // Reports list
        Expanded(
          child: StreamBuilder<List<HarassmentReport>>(
            stream: widget.adminService.getReports(status: _filterStatus),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final reports = snapshot.data ?? [];

              if (reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.report_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _filterStatus != null
                            ? 'No ${_formatStatus(_filterStatus!).toLowerCase()} reports'
                            : 'No reports found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  return _buildReportCard(reports[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(HarassmentReport report) {
    final statusColor = _getStatusColor(
      ReportReviewStatus.values.firstWhere(
        (s) => s.name == (report.toJson()['reviewStatus'] ?? 'pending'),
        orElse: () => ReportReviewStatus.pending,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showReportDetails(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(report.harassmentType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      report.harassmentType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getTypeColor(report.harassmentType),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatStatus(ReportReviewStatus.values.firstWhere(
                        (s) => s.name == (report.toJson()['reviewStatus'] ?? 'pending'),
                        orElse: () => ReportReviewStatus.pending,
                      )),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                report.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),

              // Location
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Time
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(report.reportedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              // Evidence indicator
              if (report.imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.image, size: 16, color: Colors.blue[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Photo evidence',
                        style: TextStyle(fontSize: 12, color: Colors.blue[400]),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDetails(HarassmentReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(report.harassmentType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      report.harassmentType.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getTypeColor(report.harassmentType),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ID: ${report.id.substring(0, 8)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Description
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(report.description),
              const SizedBox(height: 20),

              // Location
              const Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Color(0xFFE91E63)),
                  title: Text(report.address),
                  subtitle: Text(
                    'Lat: ${report.latitude.toStringAsFixed(6)}, Lng: ${report.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Time
              const Text(
                'Time Reported',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.access_time, color: Color(0xFFE91E63)),
                  title: Text(_formatDateTime(report.reportedAt)),
                ),
              ),
              const SizedBox(height: 20),

              // Evidence
              if (report.imagePath != null) ...[
                const Text(
                  'Photo Evidence',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    report.imagePath!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Actions
              const Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus(
                      report,
                      ReportReviewStatus.verified,
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus(
                      report,
                      ReportReviewStatus.underReview,
                    ),
                    icon: const Icon(Icons.pending),
                    label: const Text('Under Review'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showForwardDialog(report),
                    icon: const Icon(Icons.forward),
                    label: const Text('Forward'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _updateStatus(
                      report,
                      ReportReviewStatus.rejected,
                    ),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    HarassmentReport report,
    ReportReviewStatus status,
  ) async {
    try {
      await widget.adminService.updateReportStatus(
        reportId: report.id,
        status: status,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report marked as ${_formatStatus(status)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showForwardDialog(HarassmentReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forward Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select where to forward this report:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.local_police, color: Colors.blue),
              title: const Text('Police'),
              subtitle: const Text('Local law enforcement'),
              onTap: () => _forwardReport(report, 'police'),
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.green),
              title: const Text('NGO'),
              subtitle: const Text('Partner organizations'),
              onTap: () => _forwardReport(report, 'ngo'),
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.orange),
              title: const Text('Helpline'),
              subtitle: const Text('Women helpline'),
              onTap: () => _forwardReport(report, 'helpline'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _forwardReport(HarassmentReport report, String authority) async {
    Navigator.pop(context); // Close dialog
    try {
      await widget.adminService.forwardReportToAuthorities(
        reportId: report.id,
        authority: authority,
      );
      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report forwarded to $authority'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatStatus(ReportReviewStatus status) {
    switch (status) {
      case ReportReviewStatus.pending:
        return 'Pending';
      case ReportReviewStatus.underReview:
        return 'Under Review';
      case ReportReviewStatus.verified:
        return 'Verified';
      case ReportReviewStatus.rejected:
        return 'Rejected';
      case ReportReviewStatus.forwarded:
        return 'Forwarded';
      case ReportReviewStatus.resolved:
        return 'Resolved';
    }
  }

  Color _getStatusColor(ReportReviewStatus status) {
    switch (status) {
      case ReportReviewStatus.pending:
        return Colors.orange;
      case ReportReviewStatus.underReview:
        return Colors.blue;
      case ReportReviewStatus.verified:
        return Colors.green;
      case ReportReviewStatus.rejected:
        return Colors.red;
      case ReportReviewStatus.forwarded:
        return Colors.purple;
      case ReportReviewStatus.resolved:
        return Colors.teal;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'verbal':
        return Colors.orange;
      case 'physical':
        return Colors.red;
      case 'stalking':
        return Colors.purple;
      case 'cyber':
        return Colors.blue;
      case 'groping':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
