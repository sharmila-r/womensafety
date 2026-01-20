import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tvk_event_provider.dart';
import '../../models/tvk/tvk_broadcast.dart';
import '../../widgets/tvk/tvk_theme.dart';

/// Broadcast tab for sending messages to volunteers
class TVKBroadcastTab extends StatefulWidget {
  const TVKBroadcastTab({super.key});

  @override
  State<TVKBroadcastTab> createState() => _TVKBroadcastTabState();
}

class _TVKBroadcastTabState extends State<TVKBroadcastTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TVKEventProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Compose button
            _buildComposeHeader(),
            // Broadcast history
            Expanded(
              child: provider.broadcasts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: provider.refresh,
                      color: TVKColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.broadcasts.length,
                        itemBuilder: (context, index) {
                          return _buildBroadcastCard(provider.broadcasts[index], provider);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComposeHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openComposeBroadcast,
          style: ElevatedButton.styleFrom(
            backgroundColor: TVKColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.campaign),
          label: const Text(
            'Send Broadcast',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 64,
            color: TVKColors.primary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          const Text(
            'No broadcasts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: TVKColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Send a message to coordinate your team',
            style: TextStyle(color: TVKColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastCard(TVKBroadcast broadcast, TVKEventProvider provider) {
    final typeColor = _getTypeColor(broadcast.type);
    final isUnread = !broadcast.readBy.contains(provider.currentVolunteer?.odcId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewBroadcastDetails(broadcast, provider),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: typeColor,
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
                        color: typeColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            broadcast.type.icon,
                            size: 14,
                            color: typeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            broadcast.type.displayName.toUpperCase(),
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: TVKColors.zoneDanger,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatTimeAgo(broadcast.createdAt),
                      style: const TextStyle(
                        color: TVKColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  broadcast.title,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
                    color: TVKColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Message preview
                Text(
                  broadcast.message,
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
                    // Sender
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      broadcast.sentBy.name,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Audience
                    Icon(Icons.people, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      broadcast.audience.displayText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    // Read count
                    Text(
                      '${broadcast.readBy.length} read',
                      style: const TextStyle(
                        color: TVKColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(TVKBroadcastType type) {
    switch (type) {
      case TVKBroadcastType.emergency:
        return TVKColors.zoneDanger;
      case TVKBroadcastType.announcement:
        return TVKColors.primary;
      case TVKBroadcastType.reassign:
        return TVKColors.zoneWarning;
      case TVKBroadcastType.allClear:
        return TVKColors.zoneSafe;
    }
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openComposeBroadcast() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _ComposeBroadcastSheet(),
    );
  }

  void _viewBroadcastDetails(TVKBroadcast broadcast, TVKEventProvider provider) {
    // Mark as read
    provider.markBroadcastRead(broadcast.id);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BroadcastDetailSheet(broadcast: broadcast),
    );
  }
}

/// Compose broadcast bottom sheet
class _ComposeBroadcastSheet extends StatefulWidget {
  const _ComposeBroadcastSheet();

  @override
  State<_ComposeBroadcastSheet> createState() => _ComposeBroadcastSheetState();
}

class _ComposeBroadcastSheetState extends State<_ComposeBroadcastSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  TVKBroadcastType _selectedType = TVKBroadcastType.announcement;
  TVKBroadcastAudience _selectedAudience = TVKBroadcastAudience(
    type: TVKAudienceType.all,
  );
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.campaign, color: TVKColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Send Broadcast',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: TVKColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Type selection
              const Text(
                'Type',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: TVKColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: TVKBroadcastType.values.map((type) {
                  final isSelected = _selectedType == type;
                  final color = _getTypeColor(type);
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type.icon,
                          size: 16,
                          color: isSelected ? Colors.white : color,
                        ),
                        const SizedBox(width: 4),
                        Text(type.displayName),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: color.withAlpha(25),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : color,
                    ),
                    onSelected: (_) => setState(() => _selectedType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Audience selection
              const Text(
                'Audience',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: TVKColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All Volunteers'),
                    selected: _selectedAudience.type == TVKAudienceType.all,
                    selectedColor: TVKColors.primary,
                    labelStyle: TextStyle(
                      color: _selectedAudience.type == TVKAudienceType.all
                          ? Colors.white
                          : TVKColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() {
                      _selectedAudience = TVKBroadcastAudience(
                        type: TVKAudienceType.all,
                      );
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('By Role'),
                    selected: _selectedAudience.type == TVKAudienceType.role,
                    selectedColor: TVKColors.primary,
                    labelStyle: TextStyle(
                      color: _selectedAudience.type == TVKAudienceType.role
                          ? Colors.white
                          : TVKColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() {
                      _selectedAudience = TVKBroadcastAudience(
                        type: TVKAudienceType.role,
                      );
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('By Zone'),
                    selected: _selectedAudience.type == TVKAudienceType.zone,
                    selectedColor: TVKColors.primary,
                    labelStyle: TextStyle(
                      color: _selectedAudience.type == TVKAudienceType.zone
                          ? Colors.white
                          : TVKColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() {
                      _selectedAudience = TVKBroadcastAudience(
                        type: TVKAudienceType.zone,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Brief title for the broadcast',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Message
              TextFormField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Detailed message for volunteers',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Send button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendBroadcast,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getTypeColor(_selectedType),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SEND BROADCAST',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(TVKBroadcastType type) {
    switch (type) {
      case TVKBroadcastType.emergency:
        return TVKColors.zoneDanger;
      case TVKBroadcastType.announcement:
        return TVKColors.primary;
      case TVKBroadcastType.reassign:
        return TVKColors.zoneWarning;
      case TVKBroadcastType.allClear:
        return TVKColors.zoneSafe;
    }
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final provider = context.read<TVKEventProvider>();
      final broadcastId = await provider.sendBroadcast(
        type: _selectedType,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        audience: _selectedAudience,
      );

      if (broadcastId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcast sent successfully'),
            backgroundColor: TVKColors.zoneSafe,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: TVKColors.zoneDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

/// Broadcast detail bottom sheet
class _BroadcastDetailSheet extends StatelessWidget {
  final TVKBroadcast broadcast;

  const _BroadcastDetailSheet({required this.broadcast});

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(broadcast.type);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(broadcast.type.icon, color: typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      broadcast.type.displayName,
                      style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      broadcast.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: TVKColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TVKColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              broadcast.message,
              style: const TextStyle(
                fontSize: 15,
                color: TVKColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Details
          _buildDetailRow(Icons.person, 'From', broadcast.sentBy.name),
          _buildDetailRow(Icons.people, 'Audience', broadcast.audience.displayText),
          _buildDetailRow(Icons.access_time, 'Sent', _formatTime(broadcast.createdAt)),
          _buildDetailRow(Icons.done_all, 'Read by', '${broadcast.readBy.length} volunteers'),
          const SizedBox(height: 16),

          // Close button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: TVKColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: TVKColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              color: TVKColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
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

  Color _getTypeColor(TVKBroadcastType type) {
    switch (type) {
      case TVKBroadcastType.emergency:
        return TVKColors.zoneDanger;
      case TVKBroadcastType.announcement:
        return TVKColors.primary;
      case TVKBroadcastType.reassign:
        return TVKColors.zoneWarning;
      case TVKBroadcastType.allClear:
        return TVKColors.zoneSafe;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')} - ${time.day}/${time.month}/${time.year}';
  }
}
