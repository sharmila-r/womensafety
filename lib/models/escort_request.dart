import 'package:cloud_firestore/cloud_firestore.dart';

/// Escort request status
enum EscortRequestStatus {
  pending,    // Waiting for volunteer
  confirmed,  // Volunteer accepted
  inProgress, // Escort started
  completed,  // Escort finished
  cancelled,  // Cancelled by user or volunteer
}

class EscortRequest {
  final String id;
  final String userId;
  final String userName;
  final String? userPhone;
  final String eventName;
  final String eventLocation;
  final double latitude;
  final double longitude;
  final DateTime eventDateTime;
  final String? notes;
  final EscortRequestStatus status;
  final String? assignedVolunteerId;
  final String? assignedVolunteerName;
  final String? assignedVolunteerPhone;
  final String? chatId;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final double? rating;
  final String? review;

  EscortRequest({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhone,
    required this.eventName,
    required this.eventLocation,
    required this.latitude,
    required this.longitude,
    required this.eventDateTime,
    this.notes,
    this.status = EscortRequestStatus.pending,
    this.assignedVolunteerId,
    this.assignedVolunteerName,
    this.assignedVolunteerPhone,
    this.chatId,
    required this.createdAt,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.rating,
    this.review,
  });

  bool get isPending => status == EscortRequestStatus.pending;
  bool get isConfirmed => status == EscortRequestStatus.confirmed;
  bool get isInProgress => status == EscortRequestStatus.inProgress;
  bool get isCompleted => status == EscortRequestStatus.completed;
  bool get isCancelled => status == EscortRequestStatus.cancelled;
  bool get isActive => isPending || isConfirmed || isInProgress;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'eventName': eventName,
        'eventLocation': eventLocation,
        'latitude': latitude,
        'longitude': longitude,
        'eventDateTime': eventDateTime.toIso8601String(),
        'notes': notes,
        'status': status.name,
        'assignedVolunteerId': assignedVolunteerId,
        'assignedVolunteerName': assignedVolunteerName,
        'assignedVolunteerPhone': assignedVolunteerPhone,
        'chatId': chatId,
        'createdAt': createdAt.toIso8601String(),
        'confirmedAt': confirmedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'cancelledAt': cancelledAt?.toIso8601String(),
        'cancellationReason': cancellationReason,
        'rating': rating,
        'review': review,
      };

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'eventName': eventName,
        'eventLocation': eventLocation,
        'latitude': latitude,
        'longitude': longitude,
        'eventDateTime': Timestamp.fromDate(eventDateTime),
        'notes': notes,
        'status': status.name,
        'assignedVolunteerId': assignedVolunteerId,
        'assignedVolunteerName': assignedVolunteerName,
        'assignedVolunteerPhone': assignedVolunteerPhone,
        'chatId': chatId,
        'createdAt': Timestamp.fromDate(createdAt),
        'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
        'cancellationReason': cancellationReason,
        'rating': rating,
        'review': review,
      };

  factory EscortRequest.fromJson(Map<String, dynamic> json) => EscortRequest(
        id: json['id'] ?? '',
        userId: json['userId'] ?? '',
        userName: json['userName'] ?? '',
        userPhone: json['userPhone'],
        eventName: json['eventName'] ?? '',
        eventLocation: json['eventLocation'] ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        eventDateTime: DateTime.parse(json['eventDateTime']),
        notes: json['notes'],
        status: EscortRequestStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => EscortRequestStatus.pending,
        ),
        assignedVolunteerId: json['assignedVolunteerId'],
        assignedVolunteerName: json['assignedVolunteerName'],
        assignedVolunteerPhone: json['assignedVolunteerPhone'],
        chatId: json['chatId'],
        createdAt: DateTime.parse(json['createdAt']),
        confirmedAt: json['confirmedAt'] != null ? DateTime.parse(json['confirmedAt']) : null,
        completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
        cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt']) : null,
        cancellationReason: json['cancellationReason'],
        rating: (json['rating'] as num?)?.toDouble(),
        review: json['review'],
      );

  factory EscortRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EscortRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'],
      eventName: data['eventName'] ?? '',
      eventLocation: data['eventLocation'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      eventDateTime: (data['eventDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
      status: EscortRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => EscortRequestStatus.pending,
      ),
      assignedVolunteerId: data['assignedVolunteerId'],
      assignedVolunteerName: data['assignedVolunteerName'],
      assignedVolunteerPhone: data['assignedVolunteerPhone'],
      chatId: data['chatId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancellationReason: data['cancellationReason'],
      rating: (data['rating'] as num?)?.toDouble(),
      review: data['review'],
    );
  }

  EscortRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhone,
    String? eventName,
    String? eventLocation,
    double? latitude,
    double? longitude,
    DateTime? eventDateTime,
    String? notes,
    EscortRequestStatus? status,
    String? assignedVolunteerId,
    String? assignedVolunteerName,
    String? assignedVolunteerPhone,
    String? chatId,
    DateTime? createdAt,
    DateTime? confirmedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    double? rating,
    String? review,
  }) {
    return EscortRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      eventName: eventName ?? this.eventName,
      eventLocation: eventLocation ?? this.eventLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      eventDateTime: eventDateTime ?? this.eventDateTime,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      assignedVolunteerId: assignedVolunteerId ?? this.assignedVolunteerId,
      assignedVolunteerName: assignedVolunteerName ?? this.assignedVolunteerName,
      assignedVolunteerPhone: assignedVolunteerPhone ?? this.assignedVolunteerPhone,
      chatId: chatId ?? this.chatId,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      rating: rating ?? this.rating,
      review: review ?? this.review,
    );
  }
}
