import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/harassment_report.dart';
import '../models/volunteer.dart';
import 'firebase_service.dart';

/// Admin roles
enum AdminRole {
  superAdmin,    // Full access
  moderator,     // Can review reports
  verifier,      // Can verify volunteers
  viewer,        // Read-only access
}

/// Admin user model
class AdminUser {
  final String id;
  final String userId;
  final String name;
  final String email;
  final AdminRole role;
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  AdminUser({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.permissions = const [],
    required this.createdAt,
    this.lastLoginAt,
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminUser(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: AdminRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => AdminRole.viewer,
      ),
      permissions: List<String>.from(data['permissions'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  bool hasPermission(String permission) {
    if (role == AdminRole.superAdmin) return true;
    return permissions.contains(permission);
  }
}

/// Report status for admin review
enum ReportReviewStatus {
  pending,
  underReview,
  verified,
  rejected,
  forwarded,
  resolved,
}

/// Service for admin operations
class AdminService {
  final FirebaseService _firebase = FirebaseService.instance;

  String? get _userId => _firebase.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _adminsRef =>
      _firebase.firestore.collection('admins');

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _firebase.firestore.collection('harassmentReports');

  CollectionReference<Map<String, dynamic>> get _volunteersRef =>
      _firebase.firestore.collection('volunteers');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firebase.firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _auditLogsRef =>
      _firebase.firestore.collection('auditLogs');

  // ==================== ADMIN AUTH ====================

  /// Check if current user is admin
  Future<AdminUser?> getCurrentAdmin() async {
    if (_userId == null) return null;

    final snapshot = await _adminsRef
        .where('userId', isEqualTo: _userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return AdminUser.fromFirestore(snapshot.docs.first);
  }

  /// Check if user has specific permission
  Future<bool> hasPermission(String permission) async {
    final admin = await getCurrentAdmin();
    return admin?.hasPermission(permission) ?? false;
  }

  // ==================== REPORTS MANAGEMENT ====================

  /// Get all reports with optional filters
  Stream<List<HarassmentReport>> getReports({
    ReportReviewStatus? status,
    String? country,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _reportsRef;

    if (status != null) {
      query = query.where('reviewStatus', isEqualTo: status.name);
    }

    if (country != null) {
      query = query.where('country', isEqualTo: country);
    }

    query = query.orderBy('timestamp', descending: true).limit(limit);

    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return HarassmentReport.fromJson(data);
        }).toList());
  }

  /// Get pending reports count
  Future<int> getPendingReportsCount() async {
    final snapshot = await _reportsRef
        .where('reviewStatus', isEqualTo: 'pending')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Update report status
  Future<void> updateReportStatus({
    required String reportId,
    required ReportReviewStatus status,
    String? notes,
  }) async {
    final admin = await getCurrentAdmin();
    if (admin == null) throw Exception('Not authorized');

    await _reportsRef.doc(reportId).update({
      'reviewStatus': status.name,
      'reviewedBy': admin.id,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNotes': notes,
    });

    await _logAuditEvent(
      action: 'report_status_update',
      targetId: reportId,
      details: {'status': status.name, 'notes': notes},
    );
  }

  /// Forward report to authorities
  Future<void> forwardReportToAuthorities({
    required String reportId,
    required String authority, // 'police', 'ngo', 'helpline'
    String? notes,
  }) async {
    final admin = await getCurrentAdmin();
    if (admin == null) throw Exception('Not authorized');

    await _reportsRef.doc(reportId).update({
      'reviewStatus': ReportReviewStatus.forwarded.name,
      'forwardedTo': authority,
      'forwardedAt': FieldValue.serverTimestamp(),
      'forwardedBy': admin.id,
      'forwardNotes': notes,
    });

    await _logAuditEvent(
      action: 'report_forwarded',
      targetId: reportId,
      details: {'authority': authority, 'notes': notes},
    );
  }

  /// Add admin comment to report
  Future<void> addReportComment({
    required String reportId,
    required String comment,
    bool isInternal = true,
  }) async {
    final admin = await getCurrentAdmin();
    if (admin == null) throw Exception('Not authorized');

    await _reportsRef.doc(reportId).collection('comments').add({
      'adminId': admin.id,
      'adminName': admin.name,
      'comment': comment,
      'isInternal': isInternal,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== VOLUNTEER MANAGEMENT ====================

  /// Get volunteers with optional filters
  Stream<List<Volunteer>> getVolunteers({
    VerificationLevel? verificationLevel,
    String? backgroundCheckStatus,
    String? country,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _volunteersRef;

    if (verificationLevel != null) {
      query = query.where('verificationLevel', isEqualTo: verificationLevel.name);
    }

    if (backgroundCheckStatus != null) {
      query = query.where('backgroundCheckStatus', isEqualTo: backgroundCheckStatus);
    }

    if (country != null) {
      query = query.where('country', isEqualTo: country);
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Volunteer.fromFirestore(doc)).toList());
  }

  /// Get pending volunteer verifications
  Future<int> getPendingVerificationsCount() async {
    final snapshot = await _volunteersRef
        .where('verificationLevel', isEqualTo: VerificationLevel.idVerified.name)
        .where('backgroundCheckStatus', isEqualTo: 'pending')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Approve volunteer verification
  Future<void> approveVolunteer({
    required String volunteerId,
    VerificationLevel level = VerificationLevel.backgroundChecked,
    String? notes,
  }) async {
    final admin = await getCurrentAdmin();
    if (admin == null) throw Exception('Not authorized');

    await _volunteersRef.doc(volunteerId).update({
      'verificationLevel': level.name,
      'verifiedByAdminId': admin.id,
      'verifiedAt': FieldValue.serverTimestamp(),
      'verificationNotes': notes,
      'backgroundCheckStatus': 'cleared',
    });

    await _logAuditEvent(
      action: 'volunteer_approved',
      targetId: volunteerId,
      details: {'level': level.name, 'notes': notes},
    );
  }

  /// Reject volunteer verification
  Future<void> rejectVolunteer({
    required String volunteerId,
    required String reason,
  }) async {
    final admin = await getCurrentAdmin();
    if (admin == null) throw Exception('Not authorized');

    await _volunteersRef.doc(volunteerId).update({
      'backgroundCheckStatus': 'rejected',
      'rejectedByAdminId': admin.id,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });

    await _logAuditEvent(
      action: 'volunteer_rejected',
      targetId: volunteerId,
      details: {'reason': reason},
    );
  }

  /// Vouch for volunteer (NGO/trusted source)
  Future<void> vouchVolunteer({
    required String volunteerId,
    required String vouchingNgoName,
  }) async {
    final admin = await getCurrentAdmin();
    if (admin == null) throw Exception('Not authorized');

    await _volunteersRef.doc(volunteerId).update({
      'verificationLevel': VerificationLevel.trusted.name,
      'vouchedByNgoName': vouchingNgoName,
      'vouchedByAdminId': admin.id,
      'vouchedAt': FieldValue.serverTimestamp(),
    });

    await _logAuditEvent(
      action: 'volunteer_vouched',
      targetId: volunteerId,
      details: {'ngo': vouchingNgoName},
    );
  }

  // ==================== STATISTICS ====================

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = today.subtract(const Duration(days: 7));
    final thisMonth = DateTime(now.year, now.month, 1);

    // Reports stats
    final totalReports = await _reportsRef.count().get();
    final pendingReports = await _reportsRef
        .where('reviewStatus', isEqualTo: 'pending')
        .count()
        .get();
    final todayReports = await _reportsRef
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .count()
        .get();

    // Volunteer stats
    final totalVolunteers = await _volunteersRef.count().get();
    final verifiedVolunteers = await _volunteersRef
        .where('verificationLevel', whereIn: [
          VerificationLevel.backgroundChecked.name,
          VerificationLevel.trusted.name,
        ])
        .count()
        .get();
    final activeVolunteers = await _volunteersRef
        .where('availabilityStatus', isEqualTo: AvailabilityStatus.available.name)
        .count()
        .get();

    // User stats
    final totalUsers = await _usersRef.count().get();

    return {
      'reports': {
        'total': totalReports.count ?? 0,
        'pending': pendingReports.count ?? 0,
        'today': todayReports.count ?? 0,
      },
      'volunteers': {
        'total': totalVolunteers.count ?? 0,
        'verified': verifiedVolunteers.count ?? 0,
        'active': activeVolunteers.count ?? 0,
      },
      'users': {
        'total': totalUsers.count ?? 0,
      },
    };
  }

  /// Get reports by type for chart
  Future<Map<String, int>> getReportsByType() async {
    final snapshot = await _reportsRef.get();
    final counts = <String, int>{};

    for (final doc in snapshot.docs) {
      final type = doc.data()['harassmentType'] as String? ?? 'other';
      counts[type] = (counts[type] ?? 0) + 1;
    }

    return counts;
  }

  /// Get reports over time
  Future<List<Map<String, dynamic>>> getReportsTimeline({
    int days = 30,
  }) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    final snapshot = await _reportsRef
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('timestamp')
        .get();

    // Group by date
    final dailyCounts = <String, int>{};
    for (final doc in snapshot.docs) {
      final timestamp = (doc.data()['timestamp'] as Timestamp).toDate();
      final dateKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
      dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
    }

    return dailyCounts.entries
        .map((e) => {'date': e.key, 'count': e.value})
        .toList();
  }

  // ==================== AUDIT LOGGING ====================

  Future<void> _logAuditEvent({
    required String action,
    required String targetId,
    Map<String, dynamic>? details,
  }) async {
    final admin = await getCurrentAdmin();

    await _auditLogsRef.add({
      'action': action,
      'targetId': targetId,
      'adminId': admin?.id,
      'adminName': admin?.name,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get audit logs
  Stream<List<Map<String, dynamic>>> getAuditLogs({int limit = 100}) {
    return _auditLogsRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }
}
