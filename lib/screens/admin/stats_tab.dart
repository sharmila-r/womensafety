import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class StatsTab extends StatefulWidget {
  final AdminService adminService;

  const StatsTab({super.key, required this.adminService});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  Map<String, dynamic>? _stats;
  Map<String, int>? _reportsByType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await widget.adminService.getDashboardStats();
      final reportsByType = await widget.adminService.getReportsByType();
      setState(() {
        _stats = stats;
        _reportsByType = reportsByType;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Failed to load statistics'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStats,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            const Text(
              'Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildOverviewCards(),
            const SizedBox(height: 24),

            // Reports Statistics
            const Text(
              'Reports',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildReportsSection(),
            const SizedBox(height: 24),

            // Volunteers Statistics
            const Text(
              'Volunteers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildVolunteersSection(),
            const SizedBox(height: 24),

            // Reports by Type
            if (_reportsByType != null && _reportsByType!.isNotEmpty) ...[
              const Text(
                'Reports by Type',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildReportsByTypeChart(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final reports = _stats!['reports'] as Map<String, dynamic>;
    final volunteers = _stats!['volunteers'] as Map<String, dynamic>;
    final users = _stats!['users'] as Map<String, dynamic>;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard(
          icon: Icons.report,
          title: 'Total Reports',
          value: '${reports['total']}',
          color: Colors.orange,
          subtitle: '${reports['today']} today',
        ),
        _buildStatCard(
          icon: Icons.pending,
          title: 'Pending Review',
          value: '${reports['pending']}',
          color: Colors.red,
          subtitle: 'Needs attention',
        ),
        _buildStatCard(
          icon: Icons.people,
          title: 'Volunteers',
          value: '${volunteers['total']}',
          color: Colors.blue,
          subtitle: '${volunteers['verified']} verified',
        ),
        _buildStatCard(
          icon: Icons.person,
          title: 'Users',
          value: '${users['total']}',
          color: Colors.green,
          subtitle: 'Registered',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportsSection() {
    final reports = _stats!['reports'] as Map<String, dynamic>;
    final pending = reports['pending'] as int;
    final total = reports['total'] as int;
    final reviewed = total - pending;
    final reviewRate = total > 0 ? (reviewed / total * 100) : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Review Progress',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${reviewRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE91E63),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: reviewRate / 100,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('Total', '$total', Colors.blue),
                _buildMiniStat('Reviewed', '$reviewed', Colors.green),
                _buildMiniStat('Pending', '$pending', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteersSection() {
    final volunteers = _stats!['volunteers'] as Map<String, dynamic>;
    final total = volunteers['total'] as int;
    final verified = volunteers['verified'] as int;
    final active = volunteers['active'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Volunteer Status',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularStat('Total', total, Colors.blue),
                _buildCircularStat('Verified', verified, Colors.green),
                _buildCircularStat('Active', active, const Color(0xFFE91E63)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCircularStat(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildReportsByTypeChart() {
    final sortedTypes = _reportsByType!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sortedTypes.fold<int>(0, (sum, e) => sum + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sortedTypes.map((entry) {
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      _formatTypeName(entry.key),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getTypeColor(entry.key),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatTypeName(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
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
}
