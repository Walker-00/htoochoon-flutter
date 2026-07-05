import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_model.g.dart';

/// ============================
/// REGISTER REQUEST
/// ============================
@JsonSerializable()
class RegisterRequest {
  final String email;
  final String password;
  final String name;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.name,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

/// ============================
/// REGISTER RESPONSE
/// ============================
@JsonSerializable()
class RegisterResponse {
  final String message;
  final String userId;

  RegisterResponse({required this.message, required this.userId});

  factory RegisterResponse.fromJson(Map<String, dynamic> json) =>
      _$RegisterResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RegisterResponseToJson(this);
}

/// ============================
/// REQUEST OTP REQUEST
/// ============================
@JsonSerializable()
class RequestOtpRequest {
  final String email;
  final String action;

  RequestOtpRequest({required this.email, required this.action});

  factory RequestOtpRequest.fromJson(Map<String, dynamic> json) =>
      _$RequestOtpRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RequestOtpRequestToJson(this);
}

/// ============================
/// REQUEST OTP RESPONSE
/// ============================
@JsonSerializable()
class RequestOtpResponse {
  final String message;

  RequestOtpResponse({required this.message});

  factory RequestOtpResponse.fromJson(Map<String, dynamic> json) =>
      _$RequestOtpResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RequestOtpResponseToJson(this);
}

/// ============================
/// VERIFY OTP REQUEST
/// ============================
@JsonSerializable()
class VerifyOtpRequest {
  final String email;
  final String action;
  final String otp;

  VerifyOtpRequest({
    required this.email,
    required this.action,
    required this.otp,
  });

  factory VerifyOtpRequest.fromJson(Map<String, dynamic> json) =>
      _$VerifyOtpRequestFromJson(json);

  Map<String, dynamic> toJson() => _$VerifyOtpRequestToJson(this);
}

/// ============================
/// VERIFY OTP RESPONSE
/// ============================
@JsonSerializable()
class VerifyOtpResponse {
  final String message;

  VerifyOtpResponse({required this.message});

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) =>
      _$VerifyOtpResponseFromJson(json);

  Map<String, dynamic> toJson() => _$VerifyOtpResponseToJson(this);
}

/// ================= LOGIN REQUEST =================
@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

/// ================= ACCESS TOKEN WRAPPER =================
@JsonSerializable()
class AccessTokenWrapper {
  final String access_token;
  final String refresh_token;
  AccessTokenWrapper({required this.access_token, required this.refresh_token});

  factory AccessTokenWrapper.fromJson(Map<String, dynamic> json) =>
      _$AccessTokenWrapperFromJson(json);

  Map<String, dynamic> toJson() => _$AccessTokenWrapperToJson(this);
}

@JsonSerializable()
class UploadResponse {
  final String? message;

  UploadResponse({this.message});

  factory UploadResponse.fromJson(Map<String, dynamic> json) =>
      _$UploadResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UploadResponseToJson(this);
}

@JsonSerializable()
class User {
  final String id;
  final String email;
  final String name;
  final Role role;
  final bool isActive;

  final String? avatar;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? googleId;
  final bool? isTwoFactorEnabled;
  final String? twoFactorSecret;

  final List<Membership>? memberships;
  final UserCount? count;

  // Onboarding / profile enrichment fields (tolerate absence on older payloads).
  @JsonKey(includeIfNull: false)
  final DateTime? onboardedAt;
  @JsonKey(includeIfNull: false)
  final List<String>? interests;
  @JsonKey(includeIfNull: false)
  final String? heardFrom;
  @JsonKey(includeIfNull: false)
  final String? intendedRole;

  // 💳 Payment account the student pays FROM (mobile-money phone + provider).
  @JsonKey(includeIfNull: false)
  final String? paymentPhone;
  @JsonKey(includeIfNull: false)
  final String? paymentProvider;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.avatar,
    required this.createdAt,
    this.updatedAt,
    this.googleId,
    this.isTwoFactorEnabled,
    this.twoFactorSecret,
    this.memberships,
    this.count,
    this.onboardedAt,
    this.interests,
    this.heardFrom,
    this.intendedRole,
    this.paymentPhone,
    this.paymentProvider,
  });
  String? get absoluteAvatarUrl {
    if (avatar == null || avatar!.isEmpty) return null;

    const String baseUrl = "https://backend.htoochoon.com";

    return "$baseUrl$avatar";
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class Membership {
  final Role role;
  final Organization organization;

  Membership({required this.role, required this.organization});

  factory Membership.fromJson(Map<String, dynamic> json) =>
      _$MembershipFromJson(json);

  Map<String, dynamic> toJson() => _$MembershipToJson(this);
}

@JsonSerializable()
class Organization {
  final String? id;
  final String? name;
  final String? description;
  final String? email;
  final String? logoUrl;
  final String? ownerId;
  final String? createdAt;
  final String? updatedAt;
  Organization({
    this.id,
    this.name,
    this.description,
    this.email,
    this.logoUrl,
    this.ownerId,
    this.createdAt,
    this.updatedAt,
  });

  factory Organization.fromJson(Map<String, dynamic> json) =>
      _$OrganizationFromJson(json);

  Map<String, dynamic> toJson() => _$OrganizationToJson(this);
}

@JsonSerializable()
class UserCount {
  final int taughtClasses;
  final int submissions;

  UserCount({required this.taughtClasses, required this.submissions});

  factory UserCount.fromJson(Map<String, dynamic> json) =>
      _$UserCountFromJson(json);

  Map<String, dynamic> toJson() => _$UserCountToJson(this);
}

/// ================= LOGIN RESPONSE =================
@JsonSerializable()
class LoginResponse {
  final String access_token;
  final String refresh_token;
  final User data;
  LoginResponse({
    required this.access_token,
    required this.refresh_token,
    required this.data,
  });
  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

/// ============================
/// RESET PASSWORD REQUEST
/// ============================
@JsonSerializable()
class ResetPasswordRequest {
  final String email;
  final String action;
  final String otp;
  final String newPassword;

  ResetPasswordRequest({
    required this.email,
    required this.action,
    required this.otp,
    required this.newPassword,
  });

  factory ResetPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ResetPasswordRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ResetPasswordRequestToJson(this);
}

/// ============================
/// RESET PASSWORD RESPONSE
/// ============================
@JsonSerializable()
class ResetPasswordResponse {
  final String message;

  ResetPasswordResponse({required this.message});

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) =>
      _$ResetPasswordResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ResetPasswordResponseToJson(this);
}

/// ============================
/// AUTHME RESPONSE
/// ============================

@JsonSerializable()
class AuthMeResponse {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;

  AuthMeResponse({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
  });

  factory AuthMeResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthMeResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthMeResponseToJson(this);
}
