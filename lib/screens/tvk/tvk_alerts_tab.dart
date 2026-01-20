import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tvk_event_provider.dart';
import '../../models/tvk/tvk_alert.dart';
import '../../widgets/tvk/tvk_theme.dart';
import 'tvk_alert_detail_screen.dart';
import 'tvk_create_alert_screen.dart';

/// Alerts tab showing all event alerts with filters
class TVKAlertsTab extends StatefulWidget {
  const TVKAlertsTab({super.key});

  @override
  State<TVKAlertsTab> createState() => _TVKAlertsTabState();
}

class _TVKAlertsTabState extends State<TVKAlertsTab> {
  TVKAlertStatus? _statusFilter;
  TVKAlertSeverity? _severityFilter;

  @override
  Widget build(BuildContext context) {
    return Consumer<TVKEventProvider>(
      builder: (context, provider, child) {
        // Filter alerts
        List<TVKAlert> alerts = provider.alerts;
        if (_statusFilter != null) {
          alerts = alerts.where((a) => a.status == _statusFilter).toList();
        }
        if (_severityFilter != null) {
          alerts = alerts.where((a) => a.severity == _severityFilter).toList();
        }

        return Column(
          children: [
            // Filter bar
            _buildFilterBar(provider),
            // Alert list
            Expanded(
              child: alerts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: provider.refresh,
                      color: TVKColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: alerts.length,
                        itemBuilder: (context, index) {
                          return _buildAlertCard(alerts[index]);
                        },
                      ),
                    ),
            ),
            // Create alert button
            _buildCreateButton(),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(TVKEventProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Status filters
            _buildFilterChip(
              label: 'All',
              selected: _statusFilter == null,
              onSelected: () => setState(() => _statusFilter = null),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Active',
              selected: _statusFilter == TVKAlertStatus.active,
              color: TVKColors.zoneDanger,
              count: provider.activeAlerts.length,
              onSelected: () => setState(() => _statusFilter = TVKAlertStatus.active),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Acknowledged',
              selected: _statusFilter == TVKAlertStatus.acknowledged,
              color: TVKColors.zoneWarning,
              onSelected: () => setState(() => _statusFilter = TVKAlertStatus.acknowledged),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Resolved',
              selected: _statusFilter == TVKAlertStatus.resolved,
              color: TVKColors.zoneSafe,
              onSelected: () => setState(() => _statusFilter = TVKAlertStatus.resolved),
            ),
            const SizedBox(width: 16),
            // Severity filter
            Container(
              width: 1,
              height: 24,
              color: TVKColors.textSecondary.withAlpha(51),
            ),
            const SizedBox(width: 16),
            _buildSeverityFilter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    Color? color,
    int? count,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : TVKColors.textPrimary,
              fontSize: 12,
            ),
          ),
          if (count != null && count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withAlpha(51) : TVKColors.zoneDanger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: selected,
      selectedColor: color ?? TVKColors.primary,
      backgroundColor: TVKColors.background,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildSeverityFilter() {
    return PopupMenuButton<TVKAlertSeverity?>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _severityFilter != null ? TVKColors.primary : TVKColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _severityFilter?.displayName ?? 'Severity',
              style: TextStyle(
                color: _severityFilter != null ? Colors.white : TVKColors.textPrimary,
                fontSize: 12,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: _severityFilter != null ? Colors.white : TVKColors.textSecondary,
            ),
          ],
        ),
      ),
      onSelected: (value) => setState(() => _severityFilter = value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All')),
        PopupMenuItem(
          value: TVKAlertSeverity.critical,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: TVKColors.alertCritical,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Critical'),
            ],
          ),
        ),
        PopupMenuItem(
          value: TVKAlertSeverity.high,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: TVKColors.alertHigh,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('High'),
            ],
          ),
        ),
        PopupMenuItem(
          value: TVKAlertSeverity.medium,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: TVKColors.alertMedium,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Medium'),
            ],
          ),
        ),
        PopupMenuItem(
          value: TVKAlertSeverity.low,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: TVKColors.alertLow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Low'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _statusFilter == TVKAlertStatus.active
                ? Icons.check_circle_outline
                : Icons.notifications_none,
            size: 64,
            color: TVKColors.primary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            _statusFilter == TVKAlertStatus.active
                ? 'No active alerts'
                : 'No alerts found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: TVKColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusFilter == TVKAlertStatus.active
                ? 'All clear! No issues to address.'
                : 'Try adjusting your filters',
            style: const TextStyle(color: TVKColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(TVKAlert alert) {
    final severityColor = TVKTheme.getAlertSeverityColor(alert.severity.value);
    final timeAgo = _formatTimeAgo(alert.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openAlertDetail(alert),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: severityColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.severity.displayName.toUpperCase(),
                        style: TextStyle(
                          color: severityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(alert.status).withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alert.status.displayName,
                        style: TextStyle(
                          color: _getStatusColor(alert.status),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: TVKColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Type and Title
                Row(
                  children: [
                    Icon(
                      alert.type.icon,
                      color: severityColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: TVKColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Description
                Text(
                  alert.description,
                  style: const TextStyle(
                    color: TVKColors.textSecondary,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Footer
                Row(
                  children: [
                    // Location
                    if (alert.location.zoneName != null) ...[
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        alert.location.zoneName!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    // Assigned
                    if (alert.assignedTo.isNotEmpty) ...[
                      Icon(Icons.people, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${alert.assignedTo.length} assigned',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: TVKColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
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
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _createAlert,
            style: ElevatedButton.styleFrom(
              backgroundColor: TVKColors.zoneDanger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add_alert),
            label: const Text(
              'Report Alert',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TVKAlertStatus status) {
    switch (status) {
      case TVKAlertStatus.active:
        return TVKColors.zoneDanger;
      case TVKAlertStatus.acknowledged:
        return TVKColors.zoneWarning;
      case TVKAlertStatus.resolved:
        return TVKColors.zoneSafe;
      case TVKAlertStatus.escalated:
        return TVKColors.alertCritical;
    }
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openAlertDetail(TVKAlert alert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TVKAlertDetailScreen(alert: alert),
      ),
    );
  }

  void _createAlert() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TVKCreateAlertScreen(),
      ),
    );
  }
}
