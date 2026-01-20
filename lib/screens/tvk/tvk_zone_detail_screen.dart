import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tvk_event_provider.dart';
import '../../models/tvk/tvk_zone.dart';
import '../../models/tvk/tvk_event_volunteer.dart';
import '../../widgets/tvk/tvk_theme.dart';

/// Zone detail screen showing crowd stats and volunteer list
class TVKZoneDetailScreen extends StatefulWidget {
  final TVKZone zone;

  const TVKZoneDetailScreen({super.key, required this.zone});

  @override
  State<TVKZoneDetailScreen> createState() => _TVKZoneDetailScreenState();
}

class _TVKZoneDetailScreenState extends State<TVKZoneDetailScreen> {
  final _countController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _countController.text = widget.zone.currentCount.toString();
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TVKTheme.themeData,
      child: Consumer<TVKEventProvider>(
        builder: (context, provider, child) {
          // Get live zone data
          final zone = provider.getZone(widget.zone.id) ?? widget.zone;
          final volunteers = provider.getVolunteersByZone(zone.id);

          return Scaffold(
            backgroundColor: TVKColors.background,
            appBar: AppBar(
              backgroundColor: TVKTheme.getZoneStatusColor(zone.status.value),
              title: Text(zone.name),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${zone.currentCount}/${zone.capacity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  _buildStatusCard(zone),
                  const SizedBox(height: 16),

                  // Crowd Count Entry
                  _buildCrowdCountCard(zone, provider),
                  const SizedBox(height: 16),

                  // Zone Info
                  _buildZoneInfoCard(zone),
                  const SizedBox(height: 16),

                  // Assigned Volunteers
                  _buildVolunteersSection(volunteers),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(TVKZone zone) {
    final statusColor = TVKTheme.getZoneStatusColor(zone.status.value);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor, statusColor.withAlpha(204)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Status',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      zone.status.displayName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${zone.densityPercent.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Density bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Crowd Density',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '${zone.currentCount} / ${zone.capacity}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: zone.densityPercent / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withAlpha(51),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrowdCountCard(TVKZone zone, TVKEventProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, color: TVKColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Update Crowd Count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TVKColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Decrement button
                IconButton(
                  onPressed: () {
                    final current = int.tryParse(_countController.text) ?? 0;
                    if (current > 0) {
                      _countController.text = (current - 10).clamp(0, zone.capacity).toString();
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 32,
                  color: TVKColors.zoneDanger,
                ),
                // Count input
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: TVKColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      suffixText: '/ ${zone.capacity}',
                    ),
                  ),
                ),
                // Increment button
                IconButton(
                  onPressed: () {
                    final current = int.tryParse(_countController.text) ?? 0;
                    _countController.text = (current + 10).clamp(0, zone.capacity).toString();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 32,
                  color: TVKColors.zoneSafe,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quick adjust buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAdjustButton('-100', () {
                  final current = int.tryParse(_countController.text) ?? 0;
                  _countController.text = (current - 100).clamp(0, zone.capacity).toString();
                }),
                _buildQuickAdjustButton('-50', () {
                  final current = int.tryParse(_countController.text) ?? 0;
                  _countController.text = (current - 50).clamp(0, zone.capacity).toString();
                }),
                _buildQuickAdjustButton('+50', () {
                  final current = int.tryParse(_countController.text) ?? 0;
                  _countController.text = (current + 50).clamp(0, zone.capacity).toString();
                }),
                _buildQuickAdjustButton('+100', () {
                  final current = int.tryParse(_countController.text) ?? 0;
                  _countController.text = (current + 100).clamp(0, zone.capacity).toString();
                }),
              ],
            ),
            const SizedBox(height: 16),
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : () => _updateCount(zone, provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TVKColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update Count',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAdjustButton(String label, VoidCallback onTap) {
    final isNegative = label.startsWith('-');
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: isNegative ? TVKColors.zoneDanger : TVKColors.zoneSafe,
        side: BorderSide(
          color: isNegative ? TVKColors.zoneDanger : TVKColors.zoneSafe,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _updateCount(TVKZone zone, TVKEventProvider provider) async {
    final newCount = int.tryParse(_countController.text);
    if (newCount == null || newCount < 0 || newCount > zone.capacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid count (0-${zone.capacity})'),
          backgroundColor: TVKColors.zoneDanger,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await provider.updateZoneCount(zone.id, newCount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crowd count updated'),
            backgroundColor: TVKColors.zoneSafe,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: TVKColors.zoneDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Widget _buildZoneInfoCard(TVKZone zone) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: TVKColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Zone Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TVKColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Type', zone.type.displayName),
            _buildInfoRow('Capacity', '${zone.capacity} people'),
            _buildInfoRow('Last Updated', _formatTime(zone.lastUpdated)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
      ),
    );
  }

  Widget _buildVolunteersSection(List<TVKEventVolunteer> volunteers) {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TVKColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${volunteers.length}',
                style: const TextStyle(
                  color: TVKColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (volunteers.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No volunteers assigned',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...volunteers.map((volunteer) => _buildVolunteerCard(volunteer)),
      ],
    );
  }

  Widget _buildVolunteerCard(TVKEventVolunteer volunteer) {
    final roleColor = TVKTheme.getRoleColor(volunteer.role.value);
    final statusColor = TVKTheme.getVolunteerStatusColor(volunteer.status.value);

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
        subtitle: Text(volunteer.role.displayName),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                volunteer.status.displayName,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
