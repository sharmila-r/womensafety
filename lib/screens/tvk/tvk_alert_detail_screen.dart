import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tvk_event_provider.dart';
import '../../models/tvk/tvk_alert.dart';
import '../../models/tvk/tvk_event_volunteer.dart';
import '../../widgets/tvk/tvk_theme.dart';

/// Alert detail screen with actions and volunteer assignment
class TVKAlertDetailScreen extends StatefulWidget {
  final TVKAlert alert;

  const TVKAlertDetailScreen({super.key, required this.alert});

  @override
  State<TVKAlertDetailScreen> createState() => _TVKAlertDetailScreenState();
}

class _TVKAlertDetailScreenState extends State<TVKAlertDetailScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TVKTheme.themeData,
      child: Consumer<TVKEventProvider>(
        builder: (context, provider, child) {
          // Get latest alert data
          final alert = provider.alerts.firstWhere(
            (a) => a.id == widget.alert.id,
            orElse: () => widget.alert,
          );
          final severityColor = TVKTheme.getAlertSeverityColor(alert.severity.value);

          return Scaffold(
            backgroundColor: TVKColors.background,
            appBar: AppBar(
              backgroundColor: severityColor,
              title: Text(alert.type.displayName),
              actions: [
                if (alert.isActive)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) => _handleMenuAction(value, provider),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: TVKColors.textSecondary),
                            SizedBox(width: 8),
                            Text('Cancel Alert'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status header
                  _buildStatusHeader(alert, severityColor),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Alert info card
                        _buildInfoCard(alert),
                        const SizedBox(height: 16),
                        // Location card
                        _buildLocationCard(alert),
                        const SizedBox(height: 16),
                        // Creator info
                        _buildCreatorCard(alert),
                        const SizedBox(height: 16),
                        // Assigned volunteers
                        _buildAssignedVolunteers(alert, provider),
                        const SizedBox(height: 16),
                        // Available volunteers
                        if (alert.isActive || alert.status == TVKAlertStatus.acknowledged)
                          _buildAvailableVolunteers(alert, provider),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _buildActionBar(alert, provider),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(TVKAlert alert, Color severityColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [severityColor, severityColor.withAlpha(204)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusIndicatorColor(alert.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      alert.status.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  alert.severity.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            alert.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Time
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(alert.createdAt),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(TVKAlert alert) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(alert.type.icon, color: TVKColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Alert Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TVKColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              alert.description,
              style: const TextStyle(
                fontSize: 15,
                color: TVKColors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(TVKAlert alert) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: TVKColors.primary),
                SizedBox(width: 8),
                Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TVKColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (alert.location.zoneName != null) ...[
              _buildLocationRow('Zone', alert.location.zoneName!),
              const SizedBox(height: 8),
            ],
            _buildLocationRow(
              'Coordinates',
              '${alert.location.latitude.toStringAsFixed(6)}, ${alert.location.longitude.toStringAsFixed(6)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: TVKColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: TVKColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorCard(TVKAlert alert) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: TVKColors.primary.withAlpha(25),
          child: const Icon(Icons.person, color: TVKColors.primary),
        ),
        title: Text(
          alert.createdBy.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(alert.createdBy.role ?? 'Volunteer'),
        trailing: const Text(
          'Reported by',
          style: TextStyle(color: TVKColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildAssignedVolunteers(TVKAlert alert, TVKEventProvider provider) {
    final assignedVolunteers = provider.volunteers
        .where((v) => alert.assignedTo.contains(v.odcId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Assigned Volunteers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: TVKColors.textPrimary,
              ),
            ),
            if (assignedVolunteers.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TVKColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${assignedVolunteers.length}',
                  style: const TextStyle(
                    color: TVKColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (assignedVolunteers.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_add, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No volunteers assigned yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...assignedVolunteers.map((v) => _buildVolunteerCard(v, isAssigned: true)),
      ],
    );
  }

  Widget _buildAvailableVolunteers(TVKAlert alert, TVKEventProvider provider) {
    // Get available volunteers (active, not assigned to this alert)
    final availableVolunteers = provider.volunteers
        .where((v) =>
            v.isActive &&
            !alert.assignedTo.contains(v.odcId) &&
            v.odcId != provider.currentVolunteer?.odcId)
        .toList();

    if (availableVolunteers.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Volunteers',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: TVKColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...availableVolunteers.take(5).map((v) => _buildVolunteerCard(
              v,
              isAssigned: false,
              onAssign: () => _assignVolunteer(provider, alert.id, v.odcId),
            )),
        if (availableVolunteers.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+${availableVolunteers.length - 5} more available',
              style: const TextStyle(color: TVKColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildVolunteerCard(
    TVKEventVolunteer volunteer, {
    required bool isAssigned,
    VoidCallback? onAssign,
  }) {
    final roleColor = TVKTheme.getRoleColor(volunteer.role.value);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withAlpha(51),
          child: Icon(
            TVKTheme.getRoleIcon(volunteer.role.value),
            color: roleColor,
          ),
        ),
        title: Text(
          volunteer.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Text(volunteer.role.displayName),
            if (volunteer.assignedZoneName != null) ...[
              const Text(' • '),
              Text(volunteer.assignedZoneName!),
            ],
          ],
        ),
        trailing: isAssigned
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TVKColors.statusResponding.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 14, color: TVKColors.statusResponding),
                    SizedBox(width: 4),
                    Text(
                      'Assigned',
                      style: TextStyle(
                        color: TVKColors.statusResponding,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : IconButton(
                icon: const Icon(Icons.add_circle_outline, color: TVKColors.primary),
                onPressed: onAssign,
              ),
      ),
    );
  }

  Widget _buildActionBar(TVKAlert alert, TVKEventProvider provider) {
    if (alert.status == TVKAlertStatus.resolved ||
        alert.status == TVKAlertStatus.escalated) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (alert.isActive) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _acknowledgeAlert(provider, alert.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TVKColors.zoneWarning,
                    side: const BorderSide(color: TVKColors.zoneWarning),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Acknowledge'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _resolveAlert(provider, alert.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TVKColors.zoneSafe,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Mark Resolved'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusIndicatorColor(TVKAlertStatus status) {
    switch (status) {
      case TVKAlertStatus.active:
        return Colors.white;
      case TVKAlertStatus.acknowledged:
        return TVKColors.zoneWarning;
      case TVKAlertStatus.resolved:
        return TVKColors.zoneSafe;
      case TVKAlertStatus.escalated:
        return TVKColors.alertCritical;
    }
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${time.day}/${time.month}/${time.year} at ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _acknowledgeAlert(TVKEventProvider provider, String alertId) async {
    setState(() => _isProcessing = true);
    try {
      await provider.acknowledgeAlert(alertId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert acknowledged'),
            backgroundColor: TVKColors.zoneWarning,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _resolveAlert(TVKEventProvider provider, String alertId) async {
    setState(() => _isProcessing = true);
    try {
      await provider.resolveAlert(alertId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert resolved'),
            backgroundColor: TVKColors.zoneSafe,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _assignVolunteer(
    TVKEventProvider provider,
    String alertId,
    String odcId,
  ) async {
    try {
      await provider.assignVolunteersToAlert(alertId, [odcId]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volunteer assigned'),
            backgroundColor: TVKColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign: $e'),
            backgroundColor: TVKColors.zoneDanger,
          ),
        );
      }
    }
  }

  void _handleMenuAction(String action, TVKEventProvider provider) {
    if (action == 'cancel') {
      _showCancelConfirmation(provider);
    }
  }

  void _showCancelConfirmation(TVKEventProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Alert?'),
        content: const Text(
          'This will mark the alert as cancelled. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep It'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement cancel alert
            },
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: TVKColors.zoneDanger),
            ),
          ),
        ],
      ),
    );
  }
}
