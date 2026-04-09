enum AppRole { view, moderator, admin }

extension AppRoleX on AppRole {
  String get value {
    switch (this) {
      case AppRole.view:
        return 'view';
      case AppRole.moderator:
        return 'moderator';
      case AppRole.admin:
        return 'admin';
    }
  }

  String get label {
    switch (this) {
      case AppRole.view:
        return 'View';
      case AppRole.moderator:
        return 'Moderator';
      case AppRole.admin:
        return 'Admin';
    }
  }
}

AppRole appRoleFromString(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'admin':
      return AppRole.admin;
    case 'moderator':
      return AppRole.moderator;
    case 'view':
    default:
      return AppRole.view;
  }
}

class AppUserProfile {
  AppUserProfile({
    required this.uid,
    required this.username,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.authEmail,
    this.createdByUid,
  });

  final String uid;
  final String username;
  final AppRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authEmail;
  final String? createdByUid;

  factory AppUserProfile.fromMap(Map<String, dynamic> map) {
    return AppUserProfile(
      uid: (map['uid'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      role: appRoleFromString(map['role'] as String?),
      isActive: (map['isActive'] ?? true) as bool,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      authEmail: (map['authEmail'] ?? '') as String,
      createdByUid: map['createdByUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'usernameLower': username.toLowerCase(),
      'role': role.value,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'authEmail': authEmail,
      'createdByUid': createdByUid,
    };
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}
