import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tvk_event_provider.dart';
import '../../models/tvk/tvk_event_volunteer.dart';
import '../../widgets/tvk/tvk_theme.dart';

/// Team tab showing volunteers grouped by role
class TVKTeamTab extends StatefulWidget {
  const TVKTeamTab({super.key});

  @override
  State<TVKTeamTab> createState() => _TVKTeamTabState();
}

class _TVKTeamTabState extends State<TVKTeamTab> {
  TVKVolunteerRole? _roleFilter;
  TVKVolunteerStatus? _statusFilter;
  bool _showGrouped = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<TVKEventProvider>(
      builder: (context, provider, child) {
        // Filter volunteers
        List<TVKEventVolunteer> volunteers = provider.volunteers;
        if (_roleFilter != null) {
          volunteers = volunteers.where((v) => v.role == _roleFilter).toList();
        }
        if (_statusFilter != null) {
          volunteers = volunteers.where((v) => v.status == _statusFilter).toList();
        }

        return Column(
          children: [
            // Header stats
            _buildStatsHeader(provider),
            // Filter bar
            _buildFilterBar(provider),
            // Volunteer list
            Expanded(
              child: volunteers.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: provider.refresh,
                      color: TVKColors.primary,
                      child: _showGrouped && _roleFilter == null
                          ? _buildGroupedList(provider)
                          : _buildFlatList(volunteers),
                    ),
            ),
            // My status bar (if checked in)
            if (provider.currentVolunteer != null)
              _buildMyStatusBar(provider),
          ],
        );
      },
    );
  }

  Widget _buildStatsHeader(TVKEventProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: TVKColors.primary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn(
            '${provider.volunteers.length}',
            'Total',
            Icons.people,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withAlpha(51),
          ),
          _buildStatColumn(
            '${provider.activeVolunteerCount}',
            'Active',
            Icons.check_circle,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withAlpha(51),
          ),
          _buildStatColumn(
            '${provider.onBreakVolunteerCount}',
            'On Break',
            Icons.pause_circle,
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilterBar(TVKEventProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Role filter
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'All Roles',
                    selected: _roleFilter == null,
                    onSelected: () => setState(() => _roleFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ...TVKVolunteerRole.values.map((role) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: role.displayName,
                        selected: _roleFilter == role,
                        color: TVKTheme.getRoleColor(role.value),
                        onSelected: () => setState(() => _roleFilter = role),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          // Status filter dropdown
          PopupMenuButton<TVKVolunteerStatus?>(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _statusFilter != null ? TVKColors.primary : TVKColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusFilter?.displayName ?? 'Status',
                    style: TextStyle(
                      color: _statusFilter != null ? Colors.white : TVKColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: _statusFilter != null ? Colors.white : TVKColors.textSecondary,
                  ),
                ],
              ),
            ),
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All Statuses')),
              ...TVKVolunteerStatus.values.map((status) {
                return PopupMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: TVKTheme.getVolunteerStatusColor(status.value),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(status.displayName),
                    ],
                  ),
                );
              }),
            ],
          ),
          // Group toggle
          IconButton(
            icon: Icon(
              _showGrouped ? Icons.view_list : Icons.list,
              color: TVKColors.primary,
            ),
            onPressed: () => setState(() => _showGrouped = !_showGrouped),
            tooltip: _showGrouped ? 'Show flat list' : 'Group by role',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    Color? color,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : TVKColors.textPrimary,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: color ?? TVKColors.primary,
      backgroundColor: TVKColors.background,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: TVKColors.primary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          const Text(
            'No volunteers found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: TVKColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters',
            style: TextStyle(color: TVKColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(TVKEventProvider provider) {
    final grouped = provider.volunteersByRole;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        final role = entry.key;
        final volunteers = entry.value;

        // Apply status filter if set
        final filteredVolunteers = _statusFilter != null
            ? volunteers.where((v) => v.status == _statusFilter).toList()
            : volunteers;

        if (filteredVolunteers.isEmpty) return const SizedBox();

        return _buildRoleSection(role, filteredVolunteers);
      },
    );
  }

  Widget _buildRoleSection(TVKVolunteerRole role, List<TVKEventVolunteer> volunteers) {
    final roleColor = TVKTheme.getRoleColor(role.value);
    final activeCount = volunteers.where((v) => v.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: roleColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                TVKTheme.getRoleIcon(role.value),
                color: roleColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                role.displayName,
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$activeCount/${volunteers.length} active',
                style: TextStyle(
                  color: roleColor.withAlpha(179),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Volunteer cards
        ...volunteers.map((v) => _buildVolunteerCard(v)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFlatList(List<TVKEventVolunteer> volunteers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: volunteers.length,
      itemBuilder: (context, index) {
        return _buildVolunteerCard(volunteers[index]);
      },
    );
  }

  Widget _buildVolunteerCard(TVKEventVolunteer volunteer) {
    final roleColor = TVKTheme.getRoleColor(volunteer.role.value);
    final statusColor = TVKTheme.getVolunteerStatusColor(volunteer.status.value);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showVolunteerDetails(volunteer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: roleColor.withAlpha(25),
                radius: 24,
                backgroundImage: volunteer.photoUrl != null
                    ? NetworkImage(volunteer.photoUrl!)
                    : null,
                child: volunteer.photoUrl == null
                    ? Text(
                        volunteer.initials,
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      volunteer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: TVKColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          TVKTheme.getRoleIcon(volunteer.role.value),
                          size: 14,
                          color: TVKColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          volunteer.role.displayName,
                          style: const TextStyle(
                            color: TVKColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (volunteer.assignedZoneName != null) ...[
                          const Text(' • ', style: TextStyle(color: TVKColors.textSecondary)),
                          const Icon(Icons.location_on, size: 14, color: TVKColors.textSecondary),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              volunteer.assignedZoneName!,
                              style: const TextStyle(
                                color: TVKColors.textSecondary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(width: 6),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyStatusBar(TVKEventProvider provider) {
    final volunteer = provider.currentVolunteer!;
    final statusColor = TVKTheme.getVolunteerStatusColor(volunteer.status.value);

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
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: TVKColors.primary.withAlpha(25),
                  child: Text(
                    volunteer.initials,
                    style: const TextStyle(
                      color: TVKColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Status',
                        style: TextStyle(
                          color: TVKColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        volunteer.status.displayName,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick status toggle
                _buildStatusToggleButtons(provider),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusToggleButtons(TVKEventProvider provider) {
    final current = provider.currentVolunteer!.status;

    return Row(
      children: [
        if (current != TVKVolunteerStatus.active)
          _buildStatusButton(
            label: 'Go Active',
            icon: Icons.play_arrow,
            color: TVKColors.statusActive,
            onTap: () => _updateStatus(provider, TVKVolunteerStatus.active),
          ),
        if (current == TVKVolunteerStatus.active) ...[
          _buildStatusButton(
            label: 'Break',
            icon: Icons.pause,
            color: TVKColors.statusOnBreak,
            onTap: () => _updateStatus(provider, TVKVolunteerStatus.onBreak),
          ),
          const SizedBox(width: 8),
          _buildStatusButton(
            label: 'Offline',
            icon: Icons.power_settings_new,
            color: TVKColors.statusOffline,
            onTap: () => _updateStatus(provider, TVKVolunteerStatus.offline),
          ),
        ],
        if (current == TVKVolunteerStatus.onBreak)
          _buildStatusButton(
            label: 'Resume',
            icon: Icons.play_arrow,
            color: TVKColors.statusActive,
            onTap: () => _updateStatus(provider, TVKVolunteerStatus.active),
          ),
      ],
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(TVKEventProvider provider, TVKVolunteerStatus status) async {
    try {
      await provider.updateMyStatus(status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${status.displayName}'),
            backgroundColor: TVKTheme.getVolunteerStatusColor(status.value),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: TVKColors.zoneDanger,
          ),
        );
      }
    }
  }

  void _showVolunteerDetails(TVKEventVolunteer volunteer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _VolunteerDetailSheet(volunteer: volunteer),
    );
  }
}

/// Bottom sheet for volunteer details
class _VolunteerDetailSheet extends StatelessWidget {
  final TVKEventVolunteer volunteer;

  const _VolunteerDetailSheet({required this.volunteer});

  @override
  Widget build(BuildContext context) {
    final roleColor = TVKTheme.getRoleColor(volunteer.role.value);
    final statusColor = TVKTheme.getVolunteerStatusColor(volunteer.status.value);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                backgroundColor: roleColor.withAlpha(25),
                radius: 32,
                backgroundImage: volunteer.photoUrl != null
                    ? NetworkImage(volunteer.photoUrl!)
                    : null,
                child: volunteer.photoUrl == null
                    ? Text(
                        volunteer.initials,
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      volunteer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: TVKColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                TVKTheme.getRoleIcon(volunteer.role.value),
                                size: 14,
                                color: roleColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                volunteer.role.displayName,
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
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
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Details
          _buildDetailRow(Icons.phone, 'Phone', volunteer.phone),
          if (volunteer.assignedZoneName != null)
            _buildDetailRow(Icons.location_on, 'Zone', volunteer.assignedZoneName!),
          if (volunteer.locationAge != null)
            _buildDetailRow(Icons.gps_fixed, 'Last Location', volunteer.locationAge!),
          if (volunteer.checkInTime != null)
            _buildDetailRow(
              Icons.login,
              'Checked In',
              _formatTime(volunteer.checkInTime!),
            ),
          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement call
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TVKColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement message
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TVKColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: TVKColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: TVKColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: TVKColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
