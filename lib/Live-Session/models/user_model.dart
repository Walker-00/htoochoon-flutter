enum UserRole { admin, teacher, student }

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final bool isActive;
  final bool isTwoFactorEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? avatarUrl;
  final String? googleId;
  bool get isTeacher => role == UserRole.teacher || role == UserRole.admin;
  bool get isStudent => role == UserRole.student;
  bool get isAdmin => role == UserRole.admin;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    required this.isTwoFactorEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.googleId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // 🎀 Handle both nested 'data' and flat responses
    final data = json['data'] ?? json;

    return UserModel(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'User',
      email: data['email']?.toString() ?? '',
      avatarUrl: data['avatar']?.toString(),
      googleId: data['googleId']?.toString(),
      isActive: data['isActive'] ?? true,
      isTwoFactorEnabled: data['isTwoFactorEnabled'] ?? false,
      createdAt: DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(data['updatedAt'] ?? DateTime.now().toIso8601String()),
      role: _mapRole(data['role']),
    );
  }

  static UserRole _mapRole(dynamic role) {
    if (role is UserRole) return role;
    final String r = role?.toString().toUpperCase() ?? 'STUDENT';
    if (r == 'ADMIN') return UserRole.admin;
    if (r == 'TEACHER') return UserRole.teacher;
    return UserRole.student;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    // Ensure we are sending a String back to the server, not the Enum object
    'role': role.name.toUpperCase(),
    'isActive': isActive,
    'isTwoFactorEnabled': isTwoFactorEnabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'avatar': avatarUrl,
    'googleId': googleId,
  };
}