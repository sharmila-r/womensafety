class TrustedContact {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final bool isEmergencyContact;

  TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.isEmergencyContact = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'isEmergencyContact': isEmergencyContact,
      };

  factory TrustedContact.fromJson(Map<String, dynamic> json) => TrustedContact(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        email: json['email'],
        isEmergencyContact: json['isEmergencyContact'] ?? false,
      );

  TrustedContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    bool? isEmergencyContact,
  }) {
    return TrustedContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isEmergencyContact: isEmergencyContact ?? this.isEmergencyContact,
    );
  }
}
