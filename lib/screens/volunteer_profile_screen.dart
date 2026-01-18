import 'package:flutter/material.dart';
import '../models/volunteer.dart';
import '../services/volunteer_service.dart';

/// Screen showing detailed volunteer profile
class VolunteerProfileScreen extends StatefulWidget {
  final Volunteer volunteer;

  const VolunteerProfileScreen({super.key, required this.volunteer});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  final _volunteerService = VolunteerService();
  List<VolunteerRating> _ratings = [];
  bool _isLoadingRatings = true;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    try {
      _ratings = await _volunteerService.getVolunteerRatings(widget.volunteer.id);
    } catch (e) {
      // Ignore rating load errors
    }
    if (mounted) {
      setState(() => _isLoadingRatings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final volunteer = widget.volunteer;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header with photo
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFFE91E63),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFE91E63),
                      const Color(0xFFE91E63).withOpacity(0.8),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: volunteer.photoUrl != null
                            ? NetworkImage(volunteer.photoUrl!)
                            : null,
                        child: volunteer.photoUrl == null
                            ? Text(
                                volunteer.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE91E63),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      // Name
                      Text(
                        volunteer.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Verification badge
                      _buildVerificationBadge(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Row
                  _buildStatsRow(),
                  const SizedBox(height: 24),

                  // Bio
                  if (volunteer.bio != null && volunteer.bio!.isNotEmpty) ...[
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      volunteer.bio!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Verification Info
                  _buildVerificationInfo(),
                  const SizedBox(height: 24),

                  // Reviews
                  const Text(
                    'Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReviewsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge() {
    final volunteer = widget.volunteer;
    Color color;
    IconData icon;
    String label;

    switch (volunteer.verificationLevel) {
      case VerificationLevel.trusted:
        color = Colors.white;
        icon = Icons.workspace_premium;
        label = 'Trusted Volunteer';
        break;
      case VerificationLevel.backgroundChecked:
        color = Colors.white;
        icon = Icons.verified;
        label = 'Background Verified';
        break;
      case VerificationLevel.idVerified:
        color = Colors.white;
        icon = Icons.badge;
        label = 'ID Verified';
        break;
      default:
        color = Colors.white70;
        icon = Icons.pending;
        label = 'Pending Verification';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final volunteer = widget.volunteer;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.star,
            value: volunteer.averageRating > 0
                ? volunteer.averageRating.toStringAsFixed(1)
                : '-',
            label: 'Rating',
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.directions_walk,
            value: '${volunteer.totalEscorts}',
            label: 'Escorts',
            color: const Color(0xFFE91E63),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.reviews,
            value: '${volunteer.ratingCount}',
            label: 'Reviews',
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
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

  Widget _buildVerificationInfo() {
    final volunteer = widget.volunteer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, color: Color(0xFFE91E63)),
                SizedBox(width: 8),
                Text(
                  'Verification Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildVerificationItem(
              title: 'Phone Verified',
              isVerified: true,
              date: volunteer.createdAt,
            ),
            _buildVerificationItem(
              title: 'ID Verified',
              isVerified: volunteer.verificationLevel.index >= VerificationLevel.idVerified.index,
              date: volunteer.idVerifiedAt,
            ),
            _buildVerificationItem(
              title: 'Background Check',
              isVerified: volunteer.verificationLevel.index >= VerificationLevel.backgroundChecked.index,
              date: volunteer.bgvCompletedAt,
            ),
            if (volunteer.verificationLevel == VerificationLevel.trusted)
              _buildVerificationItem(
                title: 'Trusted Status',
                isVerified: true,
                date: null,
                icon: Icons.workspace_premium,
                color: Colors.purple,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationItem({
    required String title,
    required bool isVerified,
    DateTime? date,
    IconData? icon,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isVerified
                  ? (color ?? Colors.green).withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
            ),
            child: Icon(
              isVerified ? (icon ?? Icons.check) : Icons.close,
              size: 18,
              color: isVerified ? (color ?? Colors.green) : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isVerified ? Colors.black : Colors.grey,
                  ),
                ),
                if (isVerified && date != null)
                  Text(
                    'Since ${_formatDate(date)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_isLoadingRatings) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_ratings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.reviews_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No reviews yet',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _ratings.map((rating) => _buildReviewCard(rating)).toList(),
    );
  }

  Widget _buildReviewCard(VolunteerRating rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Stars
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating.rating ? Icons.star : Icons.star_border,
                      size: 18,
                      color: Colors.amber,
                    );
                  }),
                ),
                const Spacer(),
                // Date
                Text(
                  _formatDate(rating.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (rating.comment != null && rating.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                rating.comment!,
                style: TextStyle(
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
