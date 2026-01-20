import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tvk_event_provider.dart';
import '../../widgets/tvk/tvk_theme.dart';
import 'tvk_map_tab.dart';
import 'tvk_alerts_tab.dart';
import 'tvk_team_tab.dart';
import 'tvk_broadcast_tab.dart';

/// TVK Kavalan Dashboard Screen
/// Main entry point for event volunteer dashboard with bottom navigation
class TVKDashboardScreen extends StatefulWidget {
  final String eventId;
  final String odcId;

  const TVKDashboardScreen({
    super.key,
    required this.eventId,
    required this.odcId,
  });

  @override
  State<TVKDashboardScreen> createState() => _TVKDashboardScreenState();
}

class _TVKDashboardScreenState extends State<TVKDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize provider after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TVKEventProvider>().initialize(widget.eventId, widget.odcId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TVKTheme.themeData,
      child: Consumer<TVKEventProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Scaffold(
              backgroundColor: TVKColors.background,
              body: const Center(
                child: CircularProgressIndicator(color: TVKColors.primary),
              ),
            );
          }

          if (provider.error != null) {
            return Scaffold(
              backgroundColor: TVKColors.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: TVKColors.zoneDanger),
                    const SizedBox(height: 16),
                    Text(
                      provider.error!,
                      style: const TextStyle(color: TVKColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => provider.initialize(widget.eventId, widget.odcId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: TVKColors.background,
            appBar: _buildAppBar(provider),
            body: _buildBody(provider),
            bottomNavigationBar: _buildBottomNav(),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(TVKEventProvider provider) {
    return AppBar(
      backgroundColor: TVKColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TVK Kavalan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (provider.event != null)
                  Text(
                    provider.event!.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Alert badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                setState(() => _selectedIndex = 1); // Go to alerts tab
              },
            ),
            if (provider.activeAlerts.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: TVKColors.zoneDanger,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    provider.activeAlerts.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(TVKEventProvider provider) {
    switch (_selectedIndex) {
      case 0:
        return _buildMapTab(provider);
      case 1:
        return _buildAlertsTab(provider);
      case 2:
        return _buildTeamTab(provider);
      case 3:
        return _buildBroadcastTab(provider);
      default:
        return _buildMapTab(provider);
    }
  }

  Widget _buildMapTab(TVKEventProvider provider) {
    return Column(
      children: [
        // Stats bar
        _buildStatsBar(provider),
        // Critical alert banner
        if (provider.criticalAlerts.isNotEmpty)
          _buildAlertBanner(provider.criticalAlerts.first),
        // Map view
        const Expanded(
          child: TVKMapTab(),
        ),
        // Quick actions
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildStatsBar(TVKEventProvider provider) {
    final stats = provider.stats;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            stats?.formattedCrowd ?? '0',
            'Current Crowd',
            TVKColors.textPrimary,
          ),
          _buildStatItem(
            stats?.formattedDensity ?? '0%',
            'Avg Density',
            (stats?.avgDensityPercent ?? 0) > 70
                ? TVKColors.zoneWarning
                : TVKColors.textPrimary,
          ),
          _buildStatItem(
            '${provider.activeVolunteerCount}',
            'Active',
            TVKColors.statusActive,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: TVKColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertBanner(alert) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 1),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [TVKColors.zoneDanger, Color(0xFFCC0000)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: TVKColors.zoneDanger.withAlpha(102),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${alert.type.displayName}: ${alert.title}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              _buildActionButton(Icons.warning, 'View Alerts', () {
                setState(() => _selectedIndex = 1);
              }),
              const SizedBox(width: 10),
              _buildActionButton(Icons.campaign, 'Broadcast', () {
                setState(() => _selectedIndex = 3);
              }),
              const SizedBox(width: 10),
              _buildActionButton(Icons.people, 'Team', () {
                setState(() => _selectedIndex = 2);
              }),
            ],
          ),
          const SizedBox(height: 10),
          // Women Safety SOS button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to SOS screen
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.sos, size: 24),
              label: const Text(
                'WOMEN SAFETY SOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: TVKColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: TVKColors.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: TVKColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsTab(TVKEventProvider provider) {
    return const TVKAlertsTab();
  }

  Widget _buildTeamTab(TVKEventProvider provider) {
    return const TVKTeamTab();
  }

  Widget _buildBroadcastTab(TVKEventProvider provider) {
    return const TVKBroadcastTab();
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: TVKColors.primary,
      unselectedItemColor: TVKColors.textSecondary,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: 'Map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.warning_amber),
          label: 'Alerts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.groups),
          label: 'Team',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.campaign),
          label: 'Broadcast',
        ),
      ],
    );
  }
}
