import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/trusted_contact.dart';
import 'contact_import_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showPermissionBanner = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[ContactsScreen] initState called');
    _tabController = TabController(length: 4, vsync: this);
    // Don't check permission here - causes native crash on cold start
    // _checkIfShouldShowBanner();
    debugPrint('[ContactsScreen] initState complete');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkIfShouldShowBanner() async {
    // Don't show permission banner here - contact_import_screen handles permission flow
    // This avoids crashes from Permission.contacts.status without PERMISSION_CONTACTS=1
    if (mounted) {
      setState(() {
        _showPermissionBanner = false;
      });
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
    // Recheck permission when user returns
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _checkIfShouldShowBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Contacts'),
        actions: [
          IconButton(
            onPressed: () => _showAddContactDialog(context),
            icon: const Icon(Icons.person_add),
            tooltip: 'Add manually',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Emergency'),
            Tab(text: 'Backup'),
            Tab(text: 'Trusted'),
          ],
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.trustedContacts.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              // Permission banner when permanently denied
              if (_showPermissionBanner)
                _buildPermissionBanner(),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildContactsList(provider.trustedContacts, provider),
                    _buildContactsList(
                      provider.trustedContacts
                          .where((c) => c.category == ContactCategory.emergency)
                          .toList(),
                      provider,
                      emptyMessage: 'No emergency contacts',
                    ),
                    _buildContactsList(
                      provider.trustedContacts
                          .where((c) => c.category == ContactCategory.backup)
                          .toList(),
                      provider,
                      emptyMessage: 'No backup contacts',
                    ),
                    _buildContactsList(
                      provider.trustedContacts
                          .where((c) => c.category == ContactCategory.trusted)
                          .toList(),
                      provider,
                      emptyMessage: 'No trusted contacts',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openImportScreen(context),
        backgroundColor: const Color(0xFFE91E63),
        icon: const Icon(Icons.contacts),
        label: const Text('Import'),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.contacts, color: Colors.orange[700], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Access Denied',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Enable in Settings to import contacts from your phone',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _openAppSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Settings',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Permission banner when permanently denied
              if (_showPermissionBanner) ...[
                _buildPermissionBanner(),
                const SizedBox(height: 24),
              ],

              Icon(
                Icons.contacts_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No trusted contacts yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add contacts who will receive\nyour SOS alerts',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 32),

              // Import from phone button (primary)
              ElevatedButton.icon(
                onPressed: () => _openImportScreen(context),
                icon: const Icon(Icons.contacts),
                label: const Text('Import from Phone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Manual add button (secondary)
              OutlinedButton.icon(
                onPressed: () => _showAddContactDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Manually'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList(
    List<TrustedContact> contacts,
    AppProvider provider, {
    String? emptyMessage,
  }) {
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              emptyMessage ?? 'No contacts',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Sort: emergency first, then backup, then trusted
    final sortedContacts = List<TrustedContact>.from(contacts);
    sortedContacts.sort((a, b) {
      final categoryOrder = {
        ContactCategory.emergency: 0,
        ContactCategory.backup: 1,
        ContactCategory.trusted: 2,
      };
      return categoryOrder[a.category]!.compareTo(categoryOrder[b.category]!);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedContacts.length,
      itemBuilder: (context, index) {
        final contact = sortedContacts[index];
        return _buildContactCard(context, contact, provider);
      },
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    TrustedContact contact,
    AppProvider provider,
  ) {
    final categoryColor = Color(contact.categoryColorValue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showQuickCategoryDialog(context, contact, provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar with category color
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: categoryColor.withOpacity(0.1),
                    child: Text(
                      contact.name[0].toUpperCase(),
                      style: TextStyle(
                        color: categoryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (contact.category == ContactCategory.emergency)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.star,
                          size: 14,
                          color: categoryColor,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // Contact info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            contact.categoryDisplayName,
                            style: TextStyle(
                              fontSize: 10,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.phone,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    if (contact.relationship != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.relationship!,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.category, color: Colors.purple),
                      title: Text('Change Category'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      Future.delayed(Duration.zero, () {
                        _showQuickCategoryDialog(context, contact, provider);
                      });
                    },
                  ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.edit, color: Colors.blue),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      Future.delayed(Duration.zero, () {
                        _showEditContactDialog(context, contact);
                      });
                    },
                  ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      provider.removeTrustedContact(contact.id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openImportScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ContactImportScreen()),
    );
    // Recheck permission when returning from import screen
    if (mounted) _checkIfShouldShowBanner();
  }

  void _showQuickCategoryDialog(
    BuildContext context,
    TrustedContact contact,
    AppProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category for ${contact.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildCategoryOption(
                'Emergency',
                'Receives SOS alerts immediately',
                Icons.warning,
                Colors.pink,
                contact.category == ContactCategory.emergency,
                () {
                  provider.updateTrustedContact(
                    contact.copyWith(
                      category: ContactCategory.emergency,
                      isEmergencyContact: true,
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              _buildCategoryOption(
                'Backup',
                'Notified if emergency contacts unavailable',
                Icons.backup,
                Colors.orange,
                contact.category == ContactCategory.backup,
                () {
                  provider.updateTrustedContact(
                    contact.copyWith(
                      category: ContactCategory.backup,
                      isEmergencyContact: false,
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              _buildCategoryOption(
                'Trusted',
                'Can view your shared location',
                Icons.people,
                Colors.blue,
                contact.category == ContactCategory.trusted,
                () {
                  provider.updateTrustedContact(
                    contact.copyWith(
                      category: ContactCategory.trusted,
                      isEmergencyContact: false,
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    ContactCategory selectedCategory = ContactCategory.trusted;
    String? selectedRelationship;

    final relationshipOptions = [
      'Parent',
      'Spouse',
      'Sibling',
      'Child',
      'Friend',
      'Colleague',
      'Neighbor',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Category selection
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Category',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildCategoryButton(
                      'Emergency',
                      ContactCategory.emergency,
                      Colors.pink,
                      selectedCategory,
                      (cat) => setState(() => selectedCategory = cat),
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryButton(
                      'Backup',
                      ContactCategory.backup,
                      Colors.orange,
                      selectedCategory,
                      (cat) => setState(() => selectedCategory = cat),
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryButton(
                      'Trusted',
                      ContactCategory.trusted,
                      Colors.blue,
                      selectedCategory,
                      (cat) => setState(() => selectedCategory = cat),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Relationship dropdown
                DropdownButtonFormField<String?>(
                  value: selectedRelationship,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (optional)',
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Not specified'),
                    ),
                    ...relationshipOptions.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRelationship = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty) {
                  final contact = TrustedContact(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    phone: phoneController.text,
                    isEmergencyContact:
                        selectedCategory == ContactCategory.emergency,
                    category: selectedCategory,
                    relationship: selectedRelationship,
                  );
                  context.read<AppProvider>().addTrustedContact(contact);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(
    String label,
    ContactCategory category,
    Color color,
    ContactCategory selected,
    Function(ContactCategory) onSelect,
  ) {
    final isSelected = selected == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(category),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.white : color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _showEditContactDialog(BuildContext context, TrustedContact contact) {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phone);
    ContactCategory selectedCategory = contact.category;
    String? selectedRelationship = contact.relationship;

    final relationshipOptions = [
      'Parent',
      'Spouse',
      'Sibling',
      'Child',
      'Friend',
      'Colleague',
      'Neighbor',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Category selection
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Category',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildCategoryButton(
                      'Emergency',
                      ContactCategory.emergency,
                      Colors.pink,
                      selectedCategory,
                      (cat) => setState(() => selectedCategory = cat),
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryButton(
                      'Backup',
                      ContactCategory.backup,
                      Colors.orange,
                      selectedCategory,
                      (cat) => setState(() => selectedCategory = cat),
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryButton(
                      'Trusted',
                      ContactCategory.trusted,
                      Colors.blue,
                      selectedCategory,
                      (cat) => setState(() => selectedCategory = cat),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Relationship dropdown
                DropdownButtonFormField<String?>(
                  value: selectedRelationship,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (optional)',
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Not specified'),
                    ),
                    ...relationshipOptions.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRelationship = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty) {
                  final updatedContact = contact.copyWith(
                    name: nameController.text,
                    phone: phoneController.text,
                    isEmergencyContact:
                        selectedCategory == ContactCategory.emergency,
                    category: selectedCategory,
                    relationship: selectedRelationship,
                  );
                  context.read<AppProvider>().updateTrustedContact(updatedContact);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
