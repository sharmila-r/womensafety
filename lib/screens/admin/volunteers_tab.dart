import 'package:flutter/material.dart';
import '../../models/volunteer.dart';
import '../../services/admin_service.dart';

class VolunteersTab extends StatefulWidget {
  final AdminService adminService;
  final AdminUser admin;

  const VolunteersTab({
    super.key,
    required this.adminService,
    required this.admin,
  });

  @override
  State<VolunteersTab> createState() => _VolunteersTabState();
}

class _VolunteersTabState extends State<VolunteersTab> {
  VerificationLevel? _filterLevel;
  String? _filterBgStatus;

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
                  selected: _filterLevel == null && _filterBgStatus == null,
                  onSelected: (selected) {
                    setState(() {
                      _filterLevel = null;
                      _filterBgStatus = null;
                    });
                  },
                  selectedColor: const Color(0xFFE91E63).withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending Verification'),
                  selected: _filterBgStatus == 'pending',
                  onSelected: (selected) {
                    setState(() {
                      _filterBgStatus = selected ? 'pending' : null;
                      _filterLevel = null;
                    });
                  },
                  selectedColor: Colors.orange.withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Verified'),
                  selected: _filterLevel == VerificationLevel.backgroundChecked,
                  onSelected: (selected) {
                    setState(() {
                      _filterLevel = selected ? VerificationLevel.backgroundChecked : null;
                      _filterBgStatus = null;
                    });
                  },
                  selectedColor: Colors.green.withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Trusted'),
                  selected: _filterLevel == VerificationLevel.trusted,
                  onSelected: (selected) {
                    setState(() {
                      _filterLevel = selected ? VerificationLevel.trusted : null;
                      _filterBgStatus = null;
                    });
                  },
                  selectedColor: Colors.blue.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ),
        // Volunteers list
        Expanded(
          child: StreamBuilder<List<Volunteer>>(
            stream: widget.adminService.getVolunteers(
              verificationLevel: _filterLevel,
              backgroundCheckStatus: _filterBgStatus,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final volunteers = snapshot.data ?? [];

              if (volunteers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No volunteers found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: volunteers.length,
                itemBuilder: (context, index) {
                  return _buildVolunteerCard(volunteers[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVolunteerCard(Volunteer volunteer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showVolunteerDetails(volunteer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: _getVerificationColor(volunteer.verificationLevel).withOpacity(0.1),
                backgroundImage: volunteer.photoUrl != null
                    ? NetworkImage(volunteer.photoUrl!)
                    : null,
                child: volunteer.photoUrl == null
                    ? Text(
                        volunteer.name.isNotEmpty
                            ? volunteer.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 24,
                          color: _getVerificationColor(volunteer.verificationLevel),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          volunteer.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getVerificationColor(volunteer.verificationLevel)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            volunteer.verificationBadge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getVerificationColor(volunteer.verificationLevel),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      volunteer.phone,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    if (volunteer.email != null)
                      Text(
                        volunteer.email!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    // Stats row
                    Row(
                      children: [
                        _buildMiniStat(
                          Icons.directions_walk,
                          '${volunteer.totalEscorts}',
                          'escorts',
                        ),
                        const SizedBox(width: 16),
                        _buildMiniStat(
                          Icons.star,
                          volunteer.averageRating.toStringAsFixed(1),
                          '(${volunteer.ratingCount})',
                        ),
                        const SizedBox(width: 16),
                        if (volunteer.backgroundCheckStatus != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getBgStatusColor(volunteer.backgroundCheckStatus!)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'BG: ${volunteer.backgroundCheckStatus}',
                              style: TextStyle(
                                fontSize: 10,
                                color: _getBgStatusColor(volunteer.backgroundCheckStatus!),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action indicator
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Text(
          ' $label',
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
      ],
    );
  }

  void _showVolunteerDetails(Volunteer volunteer) {
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

              // Profile header
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor:
                        _getVerificationColor(volunteer.verificationLevel)
                            .withOpacity(0.1),
                    backgroundImage: volunteer.photoUrl != null
                        ? NetworkImage(volunteer.photoUrl!)
                        : null,
                    child: volunteer.photoUrl == null
                        ? Text(
                            volunteer.name.isNotEmpty
                                ? volunteer.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 32,
                              color: _getVerificationColor(
                                  volunteer.verificationLevel),
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
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getVerificationColor(
                                    volunteer.verificationLevel)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            volunteer.verificationBadge,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getVerificationColor(
                                  volunteer.verificationLevel),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Contact info
              const Text(
                'Contact Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Phone'),
                      subtitle: Text(volunteer.phone),
                    ),
                    if (volunteer.email != null)
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Email'),
                        subtitle: Text(volunteer.email!),
                      ),
                    ListTile(
                      leading: const Icon(Icons.flag),
                      title: const Text('Country'),
                      subtitle: Text(volunteer.country.toUpperCase()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bio
              if (volunteer.bio != null) ...[
                const Text(
                  'Bio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(volunteer.bio!),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Verification documents
              const Text(
                'Verification Documents',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDocumentCard(
                      title: 'ID Document',
                      url: volunteer.idDocumentUrl,
                      icon: Icons.badge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDocumentCard(
                      title: 'Selfie',
                      url: volunteer.selfieUrl,
                      icon: Icons.face,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Background check status
              const Text(
                'Background Check',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    _getBgStatusIcon(volunteer.backgroundCheckStatus ?? 'none'),
                    color: _getBgStatusColor(
                        volunteer.backgroundCheckStatus ?? 'none'),
                  ),
                  title: Text(
                    volunteer.backgroundCheckStatus?.toUpperCase() ??
                        'NOT INITIATED',
                  ),
                  subtitle: volunteer.backgroundCheckDate != null
                      ? Text(
                          'Checked on: ${_formatDate(volunteer.backgroundCheckDate!)}',
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Stats
              const Text(
                'Statistics',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.directions_walk,
                      value: '${volunteer.totalEscorts}',
                      label: 'Escorts',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.star,
                      value: volunteer.averageRating.toStringAsFixed(1),
                      label: 'Rating',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.cancel,
                      value: '${volunteer.cancelledCount}',
                      label: 'Cancelled',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Admin Actions
              const Text(
                'Admin Actions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (volunteer.verificationLevel != VerificationLevel.trusted &&
                  volunteer.verificationLevel !=
                      VerificationLevel.backgroundChecked)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _approveVolunteer(volunteer),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showVouchDialog(volunteer),
                      icon: const Icon(Icons.verified),
                      label: const Text('Vouch (NGO)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(volunteer),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                )
              else
                Card(
                  color: Colors.green.withOpacity(0.1),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 12),
                        Text(
                          'This volunteer is already verified',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String? url,
    required IconData icon,
  }) {
    return Card(
      child: InkWell(
        onTap: url != null
            ? () {
                // Show full image
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Image.network(url),
                  ),
                );
              }
            : null,
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                url != null ? icon : Icons.not_interested,
                color: url != null ? Colors.green : Colors.grey,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                url != null ? 'Uploaded' : 'Not uploaded',
                style: TextStyle(
                  fontSize: 10,
                  color: url != null ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFE91E63)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  Future<void> _approveVolunteer(Volunteer volunteer) async {
    try {
      await widget.adminService.approveVolunteer(volunteerId: volunteer.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volunteer approved successfully'),
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

  void _showVouchDialog(Volunteer volunteer) {
    final ngoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vouch for Volunteer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the name of the NGO vouching for this volunteer:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ngoController,
              decoration: const InputDecoration(
                labelText: 'NGO Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ngoController.text.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await widget.adminService.vouchVolunteer(
                    volunteerId: volunteer.id,
                    vouchingNgoName: ngoController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Volunteer vouched successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Vouch'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Volunteer volunteer) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Volunteer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await widget.adminService.rejectVolunteer(
                    volunteerId: volunteer.id,
                    reason: reasonController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Volunteer rejected'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Color _getVerificationColor(VerificationLevel level) {
    switch (level) {
      case VerificationLevel.trusted:
        return Colors.blue;
      case VerificationLevel.backgroundChecked:
        return Colors.green;
      case VerificationLevel.idVerified:
        return Colors.orange;
      case VerificationLevel.phoneVerified:
        return Colors.yellow[800]!;
      case VerificationLevel.unverified:
        return Colors.grey;
    }
  }

  Color _getBgStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'cleared':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'flagged':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getBgStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'cleared':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'flagged':
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
