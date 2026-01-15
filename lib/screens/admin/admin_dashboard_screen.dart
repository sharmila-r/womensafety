import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'reports_tab.dart';
import 'volunteers_tab.dart';
import 'stats_tab.dart';
import 'audit_logs_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  AdminUser? _currentAdmin;
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    try {
      final admin = await _adminService.getCurrentAdmin();
      setState(() {
        _currentAdmin = admin;
        _isLoading = false;
      });

      if (admin == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have admin access'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentAdmin == null) {
      return const Scaffold(
        body: Center(child: Text('Access denied')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAdmin,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Text(_currentAdmin!.name),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'role',
                enabled: false,
                child: Row(
                  children: [
                    const Icon(Icons.badge, size: 20),
                    const SizedBox(width: 8),
                    Text(_currentAdmin!.role.name.toUpperCase()),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Exit Admin'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          // Navigation Rail for larger screens
          if (MediaQuery.of(context).size.width > 600)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.grey[100],
              selectedIconTheme: const IconThemeData(color: Color(0xFFE91E63)),
              selectedLabelTextStyle: const TextStyle(color: Color(0xFFE91E63)),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard),
                  label: Text('Stats'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.report),
                  label: Text('Reports'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people),
                  label: Text('Volunteers'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history),
                  label: Text('Audit'),
                ),
              ],
            ),
          // Main content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                StatsTab(adminService: _adminService),
                ReportsTab(adminService: _adminService, admin: _currentAdmin!),
                VolunteersTab(adminService: _adminService, admin: _currentAdmin!),
                AuditLogsTab(adminService: _adminService),
              ],
            ),
          ),
        ],
      ),
      // Bottom Navigation for mobile
      bottomNavigationBar: MediaQuery.of(context).size.width <= 600
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFFE91E63),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Stats',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.report),
                  label: 'Reports',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Volunteers',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'Audit',
                ),
              ],
            )
          : null,
    );
  }
}
