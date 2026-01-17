/// Contact category for organizing trusted contacts
enum ContactCategory {
  emergency,  // Primary emergency contacts - receive SOS alerts immediately
  backup,     // Backup contacts - receive alerts if primary not available
  trusted,    // General trusted contacts - can track location when shared
}

class TrustedContact {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final bool isEmergencyContact;
  final ContactCategory category;
  final String? relationship; // e.g., "Mother", "Friend", "Colleague"
  final String? photoUrl;

  TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.isEmergencyContact = false,
    this.category = ContactCategory.trusted,
    this.relationship,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'isEmergencyContact': isEmergencyContact,
        'category': category.name,
        'relationship': relationship,
        'photoUrl': photoUrl,
      };

  factory TrustedContact.fromJson(Map<String, dynamic> json) => TrustedContact(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        email: json['email'],
        isEmergencyContact: json['isEmergencyContact'] ?? false,
        category: _categoryFromString(json['category']),
        relationship: json['relationship'],
        photoUrl: json['photoUrl'],
      );

  static ContactCategory _categoryFromString(String? value) {
    if (value == null) return ContactCategory.trusted;
    return ContactCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ContactCategory.trusted,
    );
  }

  TrustedContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    bool? isEmergencyContact,
    ContactCategory? category,
    String? relationship,
    String? photoUrl,
  }) {
    return TrustedContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isEmergencyContact: isEmergencyContact ?? this.isEmergencyContact,
      category: category ?? this.category,
      relationship: relationship ?? this.relationship,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  /// Returns display name for the category
  String get categoryDisplayName {
    switch (category) {
      case ContactCategory.emergency:
        return 'Emergency';
      case ContactCategory.backup:
        return 'Backup';
      case ContactCategory.trusted:
        return 'Trusted';
    }
  }

  /// Returns color for the category
  int get categoryColorValue {
    switch (category) {
      case ContactCategory.emergency:
        return 0xFFE91E63; // Pink/Red
      case ContactCategory.backup:
        return 0xFFFF9800; // Orange
      case ContactCategory.trusted:
        return 0xFF2196F3; // Blue
    }
  }
}
