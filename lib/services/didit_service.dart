import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// Didit Verification Service
/// Free Core KYC: ID Verification + Passive Liveness + Face Match
/// Docs: https://docs.didit.me/reference/api-full-flow
class DiditService {
  static const String _baseUrl = 'https://verification.didit.me';

  // Credentials
  final String _apiKey;

  // Workflow IDs (set these after creating workflows in Didit Console)
  String? kycWorkflowId;
  String? livenessWorkflowId;

  DiditService({
    required String apiKey,
    required String appId, // Keep for backwards compatibility
    this.kycWorkflowId,
    this.livenessWorkflowId,
  }) : _apiKey = apiKey;

  /// Default instance using environment config
  static DiditService get instance => DiditService(
    apiKey: EnvConfig.diditApiKey,
    appId: EnvConfig.diditAppId,
    kycWorkflowId: EnvConfig.diditKycWorkflowId,
    livenessWorkflowId: EnvConfig.diditLivenessWorkflowId,
  );

  /// Check if Didit is properly configured
  static bool get isConfigured => EnvConfig.isDiditConfigured;

  /// Create a KYC verification session
  /// Returns session URL to open in WebView
  Future<DiditSession> createKycSession({
    required String oderlId,
    required String userEmail,
    String? userPhone,
    Map<String, dynamic>? metadata,
  }) async {
    return _createSession(
      workflowId: kycWorkflowId ?? '',
      vendorData: oderlId,
      email: userEmail,
      phone: userPhone,
      metadata: metadata,
    );
  }

  /// Create a liveness-only verification session
  Future<DiditSession> createLivenessSession({
    required String orderId,
    String? userEmail,
    Map<String, dynamic>? metadata,
  }) async {
    return _createSession(
      workflowId: livenessWorkflowId ?? '',
      vendorData: orderId,
      email: userEmail,
      metadata: metadata,
    );
  }

  /// Create verification session
  Future<DiditSession> _createSession({
    required String workflowId,
    required String vendorData,
    String? email,
    String? phone,
    Map<String, dynamic>? metadata,
  }) async {
    if (workflowId.isEmpty) {
      throw Exception('Workflow ID not configured. Create a workflow in Didit Console first.');
    }

    if (_apiKey.isEmpty) {
      throw Exception('Didit API Key not configured.');
    }

    final body = <String, dynamic>{
      'workflow_id': workflowId,
      'vendor_data': vendorData,
    };

    if (metadata != null) {
      body['metadata'] = metadata;
    }

    // Only include contact_details if we have valid values
    // Email must not be empty string, phone should be in E.164 format
    final hasValidEmail = email != null && email.isNotEmpty;
    final hasValidPhone = phone != null && phone.isNotEmpty;

    if (hasValidEmail || hasValidPhone) {
      body['contact_details'] = {
        if (hasValidEmail) 'email': email,
        if (hasValidEmail) 'email_lang': 'en',
        if (hasValidPhone) 'phone': phone,
      };
    }

    // Debug: log request details
    print('=== DIDIT API REQUEST ===');
    print('URL: $_baseUrl/v2/session/');
    print('Workflow ID: $workflowId');
    print('API Key (first 10 chars): ${_apiKey.substring(0, _apiKey.length > 10 ? 10 : _apiKey.length)}...');
    print('Body: ${jsonEncode(body)}');

    final response = await http.post(
      Uri.parse('$_baseUrl/v2/session/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-KEY': _apiKey,
      },
      body: jsonEncode(body),
    );

    // Debug: log response
    print('=== DIDIT API RESPONSE ===');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return DiditSession.fromJson(data);
    }

    // Parse error message for better feedback
    String errorMsg = 'Failed to create session';
    try {
      final errorData = jsonDecode(response.body);
      if (errorData['message'] != null) {
        errorMsg = errorData['message'];
      } else if (errorData['detail'] != null) {
        errorMsg = errorData['detail'];
      }
    } catch (_) {
      errorMsg = response.body;
    }

    if (response.statusCode == 401) {
      throw Exception('Invalid API Key. Please check your Didit credentials in the Business Console.');
    } else if (response.statusCode == 403) {
      throw Exception('Permission denied. The workflow_id "$workflowId" may not belong to this API key. Please verify in Didit Console.');
    } else if (response.statusCode == 404) {
      throw Exception('Workflow not found. Please create a workflow in Didit Console and update the workflow_id.');
    }

    throw Exception('Didit error (${response.statusCode}): $errorMsg');
  }

  /// Get session status and results
  Future<DiditSessionResult> getSessionResult(String sessionId) async {
    print('=== DIDIT GET SESSION RESULT ===');
    print('URL: $_baseUrl/v2/session/$sessionId/decision/');

    final response = await http.get(
      Uri.parse('$_baseUrl/v2/session/$sessionId/decision/'),
      headers: {
        'Accept': 'application/json',
        'X-API-KEY': _apiKey,
      },
    );

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return DiditSessionResult.fromJson(data);
    }

    // Handle 404 - decision not ready yet
    if (response.statusCode == 404) {
      print('Decision not ready yet, returning pending status');
      return DiditSessionResult(
        sessionId: sessionId,
        decision: 'Pending',
      );
    }

    throw Exception('Failed to get session result: ${response.statusCode}');
  }

  /// Get session status
  Future<DiditSessionStatus> getSessionStatus(String sessionId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/v2/session/$sessionId/'),
      headers: {
        'Accept': 'application/json',
        'X-API-KEY': _apiKey,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return DiditSessionStatus.fromJson(data);
    }

    throw Exception('Failed to get session status: ${response.statusCode}');
  }
}

/// Didit verification session
class DiditSession {
  final String sessionId;
  final int sessionNumber;
  final String sessionToken;
  final String vendorData;
  final String status;
  final String workflowId;
  final String url; // Open this in WebView

  DiditSession({
    required this.sessionId,
    required this.sessionNumber,
    required this.sessionToken,
    required this.vendorData,
    required this.status,
    required this.workflowId,
    required this.url,
  });

  factory DiditSession.fromJson(Map<String, dynamic> json) {
    return DiditSession(
      sessionId: json['session_id'] ?? '',
      sessionNumber: json['session_number'] ?? 0,
      sessionToken: json['session_token'] ?? '',
      vendorData: json['vendor_data'] ?? '',
      status: json['status'] ?? 'Not Started',
      workflowId: json['workflow_id'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

/// Session status
class DiditSessionStatus {
  final String sessionId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DiditSessionStatus({
    required this.sessionId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory DiditSessionStatus.fromJson(Map<String, dynamic> json) {
    return DiditSessionStatus(
      sessionId: json['session_id'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  bool get isCompleted => status == 'Approved' || status == 'Declined';
  bool get isApproved => status == 'Approved';
  bool get isDeclined => status == 'Declined';
  bool get isPending => status == 'Pending' || status == 'Not Started';
}

/// Session verification result
class DiditSessionResult {
  final String sessionId;
  final String decision; // Approved, Declined, Pending
  final DocumentResult? document;
  final LivenessResult? liveness;
  final FaceMatchResult? faceMatch;
  final AmlResult? aml;

  DiditSessionResult({
    required this.sessionId,
    required this.decision,
    this.document,
    this.liveness,
    this.faceMatch,
    this.aml,
  });

  factory DiditSessionResult.fromJson(Map<String, dynamic> json) {
    return DiditSessionResult(
      sessionId: json['session_id'] ?? '',
      decision: json['decision'] ?? 'Pending',
      document: json['document'] != null
          ? DocumentResult.fromJson(json['document'])
          : null,
      liveness: json['liveness'] != null
          ? LivenessResult.fromJson(json['liveness'])
          : null,
      faceMatch: json['face_match'] != null
          ? FaceMatchResult.fromJson(json['face_match'])
          : null,
      aml: json['aml'] != null
          ? AmlResult.fromJson(json['aml'])
          : null,
    );
  }

  bool get isApproved => decision == 'Approved';
  bool get isDeclined => decision == 'Declined';
}

/// Document verification result
class DocumentResult {
  final String status;
  final String? documentType;
  final String? documentCountry;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? dateOfBirth;
  final String? documentNumber;
  final String? expiryDate;
  final String? gender;
  final String? nationality;
  final String? address;

  DocumentResult({
    required this.status,
    this.documentType,
    this.documentCountry,
    this.firstName,
    this.lastName,
    this.fullName,
    this.dateOfBirth,
    this.documentNumber,
    this.expiryDate,
    this.gender,
    this.nationality,
    this.address,
  });

  factory DocumentResult.fromJson(Map<String, dynamic> json) {
    final extracted = json['extracted_data'] as Map<String, dynamic>? ?? {};
    return DocumentResult(
      status: json['status'] ?? '',
      documentType: extracted['document_type'],
      documentCountry: extracted['document_country'],
      firstName: extracted['first_name'],
      lastName: extracted['last_name'],
      fullName: extracted['full_name'],
      dateOfBirth: extracted['date_of_birth'],
      documentNumber: extracted['document_number'],
      expiryDate: extracted['expiry_date'],
      gender: extracted['gender'],
      nationality: extracted['nationality'],
      address: extracted['address'],
    );
  }
}

/// Liveness detection result
class LivenessResult {
  final String status;
  final double? score;
  final bool passed;

  LivenessResult({
    required this.status,
    this.score,
    required this.passed,
  });

  factory LivenessResult.fromJson(Map<String, dynamic> json) {
    return LivenessResult(
      status: json['status'] ?? '',
      score: (json['score'] as num?)?.toDouble(),
      passed: json['passed'] ?? false,
    );
  }
}

/// Face match result
class FaceMatchResult {
  final String status;
  final double? similarity;
  final bool matched;

  FaceMatchResult({
    required this.status,
    this.similarity,
    required this.matched,
  });

  factory FaceMatchResult.fromJson(Map<String, dynamic> json) {
    return FaceMatchResult(
      status: json['status'] ?? '',
      similarity: (json['similarity'] as num?)?.toDouble(),
      matched: json['matched'] ?? false,
    );
  }
}

/// AML screening result
class AmlResult {
  final String status;
  final bool hasHits;
  final List<dynamic> hits;

  AmlResult({
    required this.status,
    required this.hasHits,
    required this.hits,
  });

  factory AmlResult.fromJson(Map<String, dynamic> json) {
    return AmlResult(
      status: json['status'] ?? '',
      hasHits: json['has_hits'] ?? false,
      hits: json['hits'] ?? [],
    );
  }
}
