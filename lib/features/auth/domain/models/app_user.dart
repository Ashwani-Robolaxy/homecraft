/// App user model stored in Firestore and used after login.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.updatedAt,
    this.phone,
    this.city,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? phone;
  final String? city;

  bool get isProvider => role == UserRole.provider;
  bool get isClient => role == UserRole.client;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String? ?? '',
      role: UserRole.fromString(map['role'] as String?),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
      phone: map['phone'] as String?,
      city: map['city'] as String?,
    );
  }
}

enum UserRole {
  client,
  provider;

  static UserRole fromString(String? value) {
    if (value == 'provider') return UserRole.provider;
    return UserRole.client;
  }
}
