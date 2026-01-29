import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/trusted_contact.dart';

/// Screen for importing contacts from phone with multi-select and categorization
class ContactImportScreen extends StatefulWidget {
  const ContactImportScreen({super.key});

  @override
  State<ContactImportScreen> createState() => _ContactImportScreenState();
}

class _ContactImportScreenState extends State<ContactImportScreen>
    with WidgetsBindingObserver {
  List<Contact> _phoneContacts = [];
  Set<String> _selectedContactIds = {};
  bool _isLoading = true;
  String _searchQuery = '';
  bool _hasPermission = false;
  bool _permissionDenied = false; // User explicitly denied
  bool _showExplanation = true; // Show explanation before requesting

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      // User might have granted permission in Settings
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _recheckPermission();
      });
    }
  }

  /// Check if we already have permission (without requesting)
  Future<void> _checkInitialPermission() async {
    if (!mounted) return;

    try {
      // Check current permission status WITHOUT triggering a request
      final status = await Permission.contacts.status;

      if (!mounted) return;

      if (status.isGranted || status.isLimited) {
        // Already have permission - load contacts directly
        setState(() {
          _showExplanation = false;
          _isLoading = true;
        });
        await _fetchContacts();
      } else if (status.isDenied || status.isPermanentlyDenied) {
        // Previously denied - show settings option
        setState(() {
          _showExplanation = false;
          _permissionDenied = true;
          _isLoading = false;
        });
      } else {
        // Not determined yet - show explanation screen
        setState(() {
          _showExplanation = true;
          _permissionDenied = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking permission: $e');
      setState(() {
        _showExplanation = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _recheckPermission() async {
    if (!mounted) return;

    try {
      final status = await Permission.contacts.status;

      if (!mounted) return;

      if (status.isGranted || status.isLimited) {
        // Permission granted in Settings
        setState(() {
          _permissionDenied = false;
          _showExplanation = false;
          _isLoading = true;
        });
        await _fetchContacts();
      }
    } catch (e) {
      debugPrint('Error rechecking permission: $e');
    }
  }

  /// Request permission - called when user taps "Allow Access" button
  Future<void> _requestPermission() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // This will show the native iOS permission dialog
      final hasPermission = await FlutterContacts.requestPermission();

      if (!mounted) return;

      if (hasPermission) {
        await _fetchContacts();
      } else {
        // User denied permission
        setState(() {
          _hasPermission = false;
          _permissionDenied = true;
          _showExplanation = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _showExplanation = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchContacts() async {
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      if (!mounted) return;

      // Filter out contacts without phone numbers
      final validContacts = contacts.where((c) => c.phones.isNotEmpty).toList();

      // Sort alphabetically
      validContacts.sort((a, b) => a.displayName.compareTo(b.displayName));

      setState(() {
        _phoneContacts = validContacts;
        _hasPermission = true;
        _permissionDenied = false;
        _showExplanation = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _permissionDenied = true;
          _showExplanation = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAppSettings() async {
    final opened = await openAppSettings();
    if (opened) {
      // When user returns from settings, recheck permission
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _recheckPermission();
      });
    }
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _phoneContacts;
    final query = _searchQuery.toLowerCase();
    return _phoneContacts.where((c) {
      return c.displayName.toLowerCase().contains(query) ||
          c.phones.any((p) => p.number.contains(query));
    }).toList();
  }

  void _toggleSelection(String contactId) {
    setState(() {
      if (_selectedContactIds.contains(contactId)) {
        _selectedContactIds.remove(contactId);
      } else {
        _selectedContactIds.add(contactId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedContactIds = _filteredContacts.map((c) => c.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedContactIds.clear();
    });
  }

  void _proceedToCategorization() {
    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    final selectedContacts = _phoneContacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactCategorizationScreen(
          contacts: selectedContacts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Contacts'),
        actions: [
          if (_selectedContactIds.isNotEmpty)
            TextButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear, color: Colors.white),
              label: Text(
                'Clear (${_selectedContactIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _selectedContactIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _proceedToCategorization,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Continue with ${_selectedContactIds.length} contacts',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading contacts...'),
          ],
        ),
      );
    }

    // Show explanation screen before requesting permission
    if (_showExplanation && !_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.contacts,
                  size: 64,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Import Your Contacts',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kaavala needs access to your contacts to help you quickly add trusted contacts and emergency contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your contacts are only used within the app and are never shared or uploaded.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Allow Access to Contacts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not Now'),
              ),
            ],
          ),
        ),
      );
    }

    // Permission was denied - show settings option
    if (_permissionDenied && !_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.contacts, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Contact Access Denied',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'To import contacts, please enable contact access in your device settings.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openAppSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    }

    if (_phoneContacts.isEmpty) {
      return const Center(
        child: Text('No contacts found on your device'),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // Select all / count row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredContacts.length} contacts',
                style: TextStyle(color: Colors.grey[600]),
              ),
              TextButton(
                onPressed: _selectAll,
                child: const Text('Select All'),
              ),
            ],
          ),
        ),

        // Contacts list
        Expanded(
          child: ListView.builder(
            itemCount: _filteredContacts.length,
            itemBuilder: (context, index) {
              final contact = _filteredContacts[index];
              final isSelected = _selectedContactIds.contains(contact.id);
              final phone = contact.phones.isNotEmpty
                  ? contact.phones.first.number
                  : 'No phone';

              return CheckboxListTile(
                value: isSelected,
                onChanged: (_) => _toggleSelection(contact.id),
                secondary: CircleAvatar(
                  backgroundImage: contact.photo != null
                      ? MemoryImage(contact.photo!)
                      : null,
                  backgroundColor: const Color(0xFFE91E63).withOpacity(0.1),
                  child: contact.photo == null
                      ? Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFFE91E63),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  contact.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(phone),
                activeColor: const Color(0xFFE91E63),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Screen for categorizing selected contacts before import
class ContactCategorizationScreen extends StatefulWidget {
  final List<Contact> contacts;

  const ContactCategorizationScreen({
    super.key,
    required this.contacts,
  });

  @override
  State<ContactCategorizationScreen> createState() =>
      _ContactCategorizationScreenState();
}

class _ContactCategorizationScreenState
    extends State<ContactCategorizationScreen> {
  late Map<String, ContactCategory> _categories;
  late Map<String, String?> _relationships;

  final List<String> _relationshipOptions = [
    'Parent',
    'Spouse',
    'Sibling',
    'Child',
    'Friend',
    'Colleague',
    'Neighbor',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Default all to trusted
    _categories = {
      for (var c in widget.contacts) c.id: ContactCategory.trusted
    };
    _relationships = {for (var c in widget.contacts) c.id: null};
  }

  void _setCategoryForAll(ContactCategory category) {
    setState(() {
      for (var id in _categories.keys) {
        _categories[id] = category;
      }
    });
  }

  Future<void> _importContacts() async {
    final provider = context.read<AppProvider>();
    final existingPhones = provider.trustedContacts.map((c) => c.phone).toSet();

    int imported = 0;
    int skipped = 0;

    for (final contact in widget.contacts) {
      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number
          : '';

      if (phone.isEmpty) continue;

      // Normalize phone for comparison
      final normalizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

      // Check if already exists
      if (existingPhones.any((p) => p.replaceAll(RegExp(r'[^\d+]'), '') == normalizedPhone)) {
        skipped++;
        continue;
      }

      final category = _categories[contact.id] ?? ContactCategory.trusted;
      final relationship = _relationships[contact.id];

      final trustedContact = TrustedContact(
        id: DateTime.now().millisecondsSinceEpoch.toString() + contact.id,
        name: contact.displayName,
        phone: phone,
        email: contact.emails.isNotEmpty ? contact.emails.first.address : null,
        isEmergencyContact: category == ContactCategory.emergency,
        category: category,
        relationship: relationship,
      );

      await provider.addTrustedContact(trustedContact);
      imported++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imported > 0
                ? 'Imported $imported contact${imported > 1 ? 's' : ''}${skipped > 0 ? ' ($skipped already existed)' : ''}'
                : 'All contacts already exist',
          ),
          backgroundColor: imported > 0 ? Colors.green : Colors.orange,
        ),
      );

      // Go back to contacts screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorize Contacts'),
      ),
      body: Column(
        children: [
          // Quick category buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set category for all:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildQuickCategoryButton(
                      'Emergency',
                      ContactCategory.emergency,
                      Colors.pink,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickCategoryButton(
                      'Backup',
                      ContactCategory.backup,
                      Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _buildQuickCategoryButton(
                      'Trusted',
                      ContactCategory.trusted,
                      Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Emergency contacts receive SOS alerts immediately. Backup contacts are notified if emergency contacts are unavailable.',
                    style: TextStyle(color: Colors.blue[900], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Contacts list
          Expanded(
            child: ListView.builder(
              itemCount: widget.contacts.length,
              itemBuilder: (context, index) {
                final contact = widget.contacts[index];
                return _buildContactCategoryCard(contact);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _importContacts,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Import ${widget.contacts.length} Contacts',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCategoryButton(
    String label,
    ContactCategory category,
    Color color,
  ) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _setCategoryForAll(category),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildContactCategoryCard(Contact contact) {
    final category = _categories[contact.id] ?? ContactCategory.trusted;
    final relationship = _relationships[contact.id];
    final phone = contact.phones.isNotEmpty
        ? contact.phones.first.number
        : 'No phone';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact info row
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: contact.photo != null
                      ? MemoryImage(contact.photo!)
                      : null,
                  backgroundColor: Color(category == ContactCategory.emergency
                      ? 0xFFE91E63
                      : category == ContactCategory.backup
                          ? 0xFFFF9800
                          : 0xFF2196F3).withOpacity(0.1),
                  child: contact.photo == null
                      ? Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Color(category == ContactCategory.emergency
                                ? 0xFFE91E63
                                : category == ContactCategory.backup
                                    ? 0xFFFF9800
                                    : 0xFF2196F3),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        phone,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Category selection
            Row(
              children: [
                const Text('Category: ', style: TextStyle(fontSize: 13)),
                const Spacer(),
                _buildCategoryChip(
                  contact.id,
                  'Emergency',
                  ContactCategory.emergency,
                  Colors.pink,
                ),
                const SizedBox(width: 4),
                _buildCategoryChip(
                  contact.id,
                  'Backup',
                  ContactCategory.backup,
                  Colors.orange,
                ),
                const SizedBox(width: 4),
                _buildCategoryChip(
                  contact.id,
                  'Trusted',
                  ContactCategory.trusted,
                  Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Relationship dropdown
            Row(
              children: [
                const Text('Relationship: ', style: TextStyle(fontSize: 13)),
                const Spacer(),
                DropdownButton<String?>(
                  value: relationship,
                  hint: const Text('Select...'),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Not specified'),
                    ),
                    ..._relationshipOptions.map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _relationships[contact.id] = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    String contactId,
    String label,
    ContactCategory category,
    Color color,
  ) {
    final isSelected = _categories[contactId] == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _categories[contactId] = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
