import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'user_model.g.dart';

/// REQUEST
@JsonSerializable()
class CreateUserRequest {
  final String email;
  final String password;
  final String name;
  final Role role;
  final String? organizationId;
  final String? schoolId;

  CreateUserRequest({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    this.organizationId,
    this.schoolId,
  });

  factory CreateUserRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateUserRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateUserRequestToJson(this);
}

/// RESPONSE
@JsonSerializable()
class UserResponse {
  final String id;
  final String email;
  final String name;
  final Role role;
  final bool isActive;
  final String? organizationId;
  final String? schoolId;
  final bool isTwoFactorEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserResponse({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.organizationId,
    this.schoolId,
    required this.isTwoFactorEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) =>
      _$UserResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UserResponseToJson(this);
}
