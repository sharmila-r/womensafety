import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Danger zone cluster for heatmap visualization
class DangerCluster {
  final double latitude;
  final double longitude;
  final int reportCount;
  final double intensity; // 0.0 to 1.0
  final String severity; // low, medium, high
  final List<String> incidentTypes;
  final DateTime? lastReportedAt;

  DangerCluster({
    required this.latitude,
    required this.longitude,
    required this.reportCount,
    required this.intensity,
    required this.severity,
    required this.incidentTypes,
    this.lastReportedAt,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// Get marker color based on severity
  double get hue {
    switch (severity) {
      case 'high':
        return BitmapDescriptor.hueRed;
      case 'medium':
        return BitmapDescriptor.hueOrange;
      default:
        return BitmapDescriptor.hueYellow;
    }
  }
}

/// Heatmap data point for visualization
class HeatmapPoint {
  final LatLng location;
  final double weight;

  HeatmapPoint({required this.location, required this.weight});
}

/// Service for generating anonymous danger zone heatmaps
class HeatmapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Grid cell size for clustering (in degrees, ~100m at equator)
  static const double _gridCellSize = 0.001;

  // Minimum reports to show a cluster (for privacy)
  static const int _minReportsForCluster = 3;

  // Time windows for recency scoring
  static const int _recentDays = 30;
  static const int _oldDays = 365;

  /// Get danger clusters for a region
  Future<List<DangerCluster>> getDangerClusters({
    required double centerLat,
    required double centerLng,
    double radiusKm = 10,
  }) async {
    // Calculate bounding box
    final latDelta = radiusKm / 111.0; // 1 degree ≈ 111km
    final lngDelta = radiusKm / (111.0 * cos(centerLat * pi / 180));

    final minLat = centerLat - latDelta;
    final maxLat = centerLat + latDelta;
    final minLng = centerLng - lngDelta;
    final maxLng = centerLng + lngDelta;

    // Fetch reports in region
    final snapshot = await _firestore
        .collection('harassmentReports')
        .where('latitude', isGreaterThan: minLat)
        .where('latitude', isLessThan: maxLat)
        .get();

    // Filter by longitude (Firestore doesn't support compound geo queries)
    final reports = snapshot.docs.where((doc) {
      final data = doc.data();
      final lng = data['longitude'] as double?;
      return lng != null && lng >= minLng && lng <= maxLng;
    }).toList();

    // Group reports into grid cells
    final clusters = <String, List<Map<String, dynamic>>>{};
    for (final doc in reports) {
      final data = doc.data();
      final lat = data['latitude'] as double;
      final lng = data['longitude'] as double;

      // Calculate grid cell
      final cellLat = (lat / _gridCellSize).floor() * _gridCellSize;
      final cellLng = (lng / _gridCellSize).floor() * _gridCellSize;
      final cellKey = '${cellLat.toStringAsFixed(4)},${cellLng.toStringAsFixed(4)}';

      clusters.putIfAbsent(cellKey, () => []);
      clusters[cellKey]!.add(data);
    }

    // Convert to danger clusters (only if minimum reports met)
    final dangerClusters = <DangerCluster>[];
    for (final entry in clusters.entries) {
      final reports = entry.value;
      if (reports.length < _minReportsForCluster) continue;

      // Calculate cluster center
      final centerLat = reports.map((r) => r['latitude'] as double).reduce((a, b) => a + b) / reports.length;
      final centerLng = reports.map((r) => r['longitude'] as double).reduce((a, b) => a + b) / reports.length;

      // Collect incident types (anonymized)
      final types = reports
          .map((r) => r['harassmentType'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      // Calculate intensity based on count and recency
      final intensity = _calculateIntensity(reports);

      // Determine severity
      String severity;
      if (reports.length >= 10 || intensity > 0.7) {
        severity = 'high';
      } else if (reports.length >= 5 || intensity > 0.4) {
        severity = 'medium';
      } else {
        severity = 'low';
      }

      // Get most recent report date
      DateTime? lastReported;
      for (final r in reports) {
        final reportedAt = r['reportedAt'] as String?;
        if (reportedAt != null) {
          final date = DateTime.tryParse(reportedAt);
          if (date != null && (lastReported == null || date.isAfter(lastReported))) {
            lastReported = date;
          }
        }
      }

      dangerClusters.add(DangerCluster(
        latitude: centerLat,
        longitude: centerLng,
        reportCount: reports.length,
        intensity: intensity,
        severity: severity,
        incidentTypes: types,
        lastReportedAt: lastReported,
      ));
    }

    return dangerClusters;
  }

  /// Get heatmap points for visualization
  Future<List<HeatmapPoint>> getHeatmapPoints({
    required double centerLat,
    required double centerLng,
    double radiusKm = 10,
  }) async {
    final clusters = await getDangerClusters(
      centerLat: centerLat,
      centerLng: centerLng,
      radiusKm: radiusKm,
    );

    return clusters.map((cluster) => HeatmapPoint(
      location: cluster.latLng,
      weight: cluster.intensity,
    )).toList();
  }

  /// Calculate intensity score based on report count and recency
  double _calculateIntensity(List<Map<String, dynamic>> reports) {
    final now = DateTime.now();
    double totalScore = 0;

    for (final report in reports) {
      final reportedAt = report['reportedAt'] as String?;
      if (reportedAt == null) {
        totalScore += 0.3; // Base score for reports without date
        continue;
      }

      final date = DateTime.tryParse(reportedAt);
      if (date == null) {
        totalScore += 0.3;
        continue;
      }

      final daysAgo = now.difference(date).inDays;
      if (daysAgo <= _recentDays) {
        totalScore += 1.0; // Recent reports have full weight
      } else if (daysAgo <= _oldDays) {
        // Linear decay for older reports
        totalScore += 1.0 - (daysAgo - _recentDays) / (_oldDays - _recentDays);
      } else {
        totalScore += 0.1; // Minimal weight for very old reports
      }
    }

    // Normalize to 0-1 range (10+ weighted reports = max intensity)
    return (totalScore / 10).clamp(0.0, 1.0);
  }

  /// Get city-wide statistics (anonymized)
  Future<Map<String, dynamic>> getCityStats({
    required double centerLat,
    required double centerLng,
    double radiusKm = 50,
  }) async {
    final clusters = await getDangerClusters(
      centerLat: centerLat,
      centerLng: centerLng,
      radiusKm: radiusKm,
    );

    final totalReports = clusters.fold<int>(0, (sum, c) => sum + c.reportCount);
    final highRiskZones = clusters.where((c) => c.severity == 'high').length;
    final mediumRiskZones = clusters.where((c) => c.severity == 'medium').length;

    // Aggregate incident types
    final typeCount = <String, int>{};
    for (final cluster in clusters) {
      for (final type in cluster.incidentTypes) {
        typeCount[type] = (typeCount[type] ?? 0) + cluster.reportCount;
      }
    }

    return {
      'totalIncidents': totalReports,
      'totalZones': clusters.length,
      'highRiskZones': highRiskZones,
      'mediumRiskZones': mediumRiskZones,
      'incidentTypes': typeCount,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Get top danger zones in a region
  Future<List<DangerCluster>> getTopDangerZones({
    required double centerLat,
    required double centerLng,
    double radiusKm = 10,
    int limit = 5,
  }) async {
    final clusters = await getDangerClusters(
      centerLat: centerLat,
      centerLng: centerLng,
      radiusKm: radiusKm,
    );

    // Sort by intensity (descending)
    clusters.sort((a, b) => b.intensity.compareTo(a.intensity));

    return clusters.take(limit).toList();
  }

  /// Check if a specific location is in a danger zone
  Future<DangerCluster?> checkLocationRisk({
    required double latitude,
    required double longitude,
    double radiusKm = 0.5,
  }) async {
    final clusters = await getDangerClusters(
      centerLat: latitude,
      centerLng: longitude,
      radiusKm: radiusKm,
    );

    if (clusters.isEmpty) return null;

    // Find nearest cluster
    DangerCluster? nearest;
    double minDistance = double.infinity;

    for (final cluster in clusters) {
      final distance = _haversineDistance(
        latitude, longitude,
        cluster.latitude, cluster.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = cluster;
      }
    }

    // Return if within 200m
    if (minDistance <= 0.2) {
      return nearest;
    }
    return null;
  }

  /// Calculate haversine distance in km
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}
