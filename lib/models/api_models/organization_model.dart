import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:json_annotation/json_annotation.dart';

part 'organization_model.g.dart';

/// REQUEST
@JsonSerializable()
class OrganizationRequest {
  final String name;
  final String email;
  final String? description;
  final String? logoUrl;
  final String? category;
  final String? phone;
  final String? address;
  final String? website;
  final Map<String, String>? socialLinks;

  // 💳 Payment account the org receives enrollment payments on.
  final String? paymentPhone;
  final String? paymentProvider;
  final String? paymentAccountName;

  OrganizationRequest({
    required this.name,
    required this.email,
    this.description,
    this.logoUrl,
    this.category,
    this.phone,
    this.address,
    this.website,
    this.socialLinks,
    this.paymentPhone,
    this.paymentProvider,
    this.paymentAccountName,
  });

  factory OrganizationRequest.fromJson(Map<String, dynamic> json) =>
      _$OrganizationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OrganizationRequestToJson(this);
}

@JsonSerializable()
class OrgResForProgramResponse {
  final String name;
  final String? id;
  final String? description;
  final String? logoUrl;
  final String? category;
  final String? email;
  final String? phone;
  final String? website;

  // 💳 Where the org receives enrollment payments (fake payment flow).
  final String? paymentPhone;
  final String? paymentProvider;
  final String? paymentAccountName;

  OrgResForProgramResponse({
    required this.name,
    this.id,
    this.description,
    this.logoUrl,
    this.category,
    this.email,
    this.phone,
    this.website,
    this.paymentPhone,
    this.paymentProvider,
    this.paymentAccountName,
  });
  factory OrgResForProgramResponse.fromJson(Map<String, dynamic> json) =>
      _$OrgResForProgramResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OrgResForProgramResponseToJson(this);
}

/// RESPONSE
@JsonSerializable()
class OrganizationResponse {
  final String id;
  final String name;
  final String email;
  final String? description;
  final String? logoUrl;
  final String? category;
  final String? phone;
  final String? address;
  final String? website;
  final Map<String, dynamic>? socialLinks;
  final String? ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 💳 Where the org receives enrollment payments (fake payment flow).
  final String? paymentPhone;
  final String? paymentProvider;
  final String? paymentAccountName;

  OrganizationResponse({
    required this.id,
    required this.name,
    required this.email,
    this.description,
    this.logoUrl,
    this.category,
    this.phone,
    this.address,
    this.website,
    this.socialLinks,
    this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.paymentPhone,
    this.paymentProvider,
    this.paymentAccountName,
  });

  factory OrganizationResponse.fromJson(Map<String, dynamic> json) =>
      _$OrganizationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OrganizationResponseToJson(this);
}

/// Organisation member
@JsonSerializable()
class OrganisationMember {
  final String id;
  final String organizationId;
  final String userId;
  final Role role;
  final DateTime joinedAt;
  final bool isActive;
  final String? invitedById;

  final OrgUser user; // ✅ nested user
  final InvitedBy? invitedBy; // ✅ nullable

  OrganisationMember({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.isActive,
    this.invitedById,
    required this.user,
    this.invitedBy,
  });

  factory OrganisationMember.fromJson(Map<String, dynamic> json) =>
      _$OrganisationMemberFromJson(json);

  Map<String, dynamic> toJson() => _$OrganisationMemberToJson(this);
}

@JsonSerializable()
class OrgUser {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final Role role;
  final bool isActive;

  OrgUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    required this.role,
    required this.isActive,
  });

  factory OrgUser.fromJson(Map<String, dynamic> json) =>
      _$OrgUserFromJson(json);

  Map<String, dynamic> toJson() => _$OrgUserToJson(this);
}

@JsonSerializable()
class InvitedBy {
  final String id;
  final String name;

  InvitedBy({required this.id, required this.name});

  factory InvitedBy.fromJson(Map<String, dynamic> json) =>
      _$InvitedByFromJson(json);

  Map<String, dynamic> toJson() => _$InvitedByToJson(this);
}

@JsonSerializable()
class OrganisationMemberRequest {
  final String userId;
  final String role;

  OrganisationMemberRequest({required this.userId, required this.role});

  factory OrganisationMemberRequest.fromJson(Map<String, dynamic> json) =>
      _$OrganisationMemberRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OrganisationMemberRequestToJson(this);
}
