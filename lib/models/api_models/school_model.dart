import 'package:json_annotation/json_annotation.dart';

part 'school_model.g.dart';

/// ======================
/// REQUESTS
/// ======================

@JsonSerializable()
class SchoolRequest {
  final String name;
  final String email;
  final String? address;

  SchoolRequest({required this.name, required this.email, this.address});

  factory SchoolRequest.fromJson(Map<String, dynamic> json) =>
      _$SchoolRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SchoolRequestToJson(this);
}

@JsonSerializable(includeIfNull: false)
class UpdateSchoolRequest {
  final String? name;
  final String? email;
  final String? address;

  UpdateSchoolRequest({this.name, this.email, this.address});

  factory UpdateSchoolRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateSchoolRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateSchoolRequestToJson(this);
}

/// ======================
/// RESPONSE
/// ======================

@JsonSerializable()
class SchoolResponse {
  final String id;
  final String name;
  final String email;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  SchoolResponse({
    required this.id,
    required this.name,
    required this.email,
    this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SchoolResponse.fromJson(Map<String, dynamic> json) =>
      _$SchoolResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SchoolResponseToJson(this);
}
