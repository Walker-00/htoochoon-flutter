import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'class_model.g.dart';

@JsonSerializable()
class ClassRequest {
  final String name;
  final String courseId;
  final DateTime startDate;
  final DateTime endDate;
  final int maxStudents;
  final String teacherId;
  final String organizationId;

  ClassRequest({
    required this.name,
    required this.courseId,
    required this.startDate,
    required this.endDate,
    required this.maxStudents,
    required this.teacherId,
    required this.organizationId,
  });
  factory ClassRequest.fromJson(Map<String, dynamic> json) =>
      _$ClassRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ClassRequestToJson(this);
}

@JsonSerializable()
class ClassCourse {
  final String id;
  final String name;

  ClassCourse({required this.id, required this.name});

  factory ClassCourse.fromJson(Map<String, dynamic> json) =>
      _$ClassCourseFromJson(json);

  Map<String, dynamic> toJson() => _$ClassCourseToJson(this);
}

@JsonSerializable()
class ClassTeacher {
  final String id;
  final String name;
  final String? email;

  ClassTeacher({required this.id, required this.name, this.email});

  factory ClassTeacher.fromJson(Map<String, dynamic> json) =>
      _$ClassTeacherFromJson(json);

  Map<String, dynamic> toJson() => _$ClassTeacherToJson(this);
}

@JsonSerializable()
class ClassResponse {
  final List<ClassModel> data;
  final Meta meta;

  ClassResponse({required this.data, required this.meta});

  factory ClassResponse.fromJson(Map<String, dynamic> json) =>
      _$ClassResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ClassResponseToJson(this);
}

@JsonSerializable()
class ClassModel {
  final String? id;
  final String? name;
  final String? courseId;

  @JsonKey(defaultValue: null)
  final ClassCourse? course;

  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxStudents;
  final String? teacherId;
  final bool? isActive;

  @JsonKey(defaultValue: null)
  final ClassTeacher? teacher;

  @JsonKey(defaultValue: [])
  final List<dynamic> members;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? organizationId;

  ClassModel({
    this.id,
    this.name,
    this.courseId,
    this.course,
    this.startDate,
    this.endDate,
    this.maxStudents,
    this.teacherId,
    this.isActive, // ✅ add
    this.teacher,
    this.members = const [], // ✅ add
    this.createdAt,
    this.updatedAt,
    this.organizationId,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) =>
      _$ClassModelFromJson(json);

  Map<String, dynamic> toJson() => _$ClassModelToJson(this);
}
// @JsonSerializable()
// class ClassModel {
//   final String id;
//   final String name;
//
//   final String? courseId;
//   @JsonKey(defaultValue: null)
//   final ClassCourse? course;
//
//   final DateTime startDate;
//   final DateTime endDate;
//
//   final int maxStudents;
//
//   final String teacherId;
//   @JsonKey(defaultValue: null)
//   final ClassTeacher? teacher;
//
//   final DateTime createdAt;
//   final DateTime updatedAt;
//   final String? organizationId;
//
//   ClassModel({
//     required this.id,
//     required this.name,
//     this.courseId,
//     this.course,
//     required this.startDate,
//     required this.endDate,
//     required this.maxStudents,
//     required this.teacherId,
//     this.teacher,
//     required this.createdAt,
//     required this.updatedAt,
//     this.organizationId,
//     // required this.organizationId,
//   });
//
//   factory ClassModel.fromJson(Map<String, dynamic> json) =>
//       _$ClassModelFromJson(json);
//
//   Map<String, dynamic> toJson() => _$ClassModelToJson(this);
// }

@JsonSerializable()
class ClassStudentRequest {
  final String userId;

  ClassStudentRequest({required this.userId});

  factory ClassStudentRequest.fromJson(Map<String, dynamic> json) =>
      _$ClassStudentRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ClassStudentRequestToJson(this);
}

@JsonSerializable()
class ClassStudentsResponse {
  final List<ClassStudentData> data;

  final Meta meta;

  ClassStudentsResponse({required this.data, required this.meta});

  factory ClassStudentsResponse.fromJson(Map<String, dynamic> json) =>
      _$ClassStudentsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ClassStudentsResponseToJson(this);
}

@JsonSerializable()
class ClassStudentData {
  final String id;

  final String classId;

  final String userId;

  final String role;

  final DateTime joinedAt;

  final Student students;

  ClassStudentData({
    required this.id,

    required this.classId,

    required this.userId,

    required this.role,

    required this.joinedAt,

    required this.students,
  });

  factory ClassStudentData.fromJson(Map<String, dynamic> json) =>
      _$ClassStudentDataFromJson(json);

  Map<String, dynamic> toJson() => _$ClassStudentDataToJson(this);
}

@JsonSerializable()
class Student {
  final String id;

  final String name;

  final String email;

  final String? avatar;

  Student({
    required this.id,

    required this.name,

    required this.email,

    this.avatar,
  });

  factory Student.fromJson(Map<String, dynamic> json) =>
      _$StudentFromJson(json);

  Map<String, dynamic> toJson() => _$StudentToJson(this);
}

@JsonSerializable()
class AddStudentResponse {
  final String? messsage;

  AddStudentResponse({this.messsage});
  factory AddStudentResponse.fromJson(Map<String, dynamic> json) =>
      _$AddStudentResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AddStudentResponseToJson(this);
}

@JsonSerializable()
class ClassItem {
  final String id;
  final String name;
  final String courseId;
  final Course course;
  final DateTime startDate;
  final DateTime endDate;
  final int maxStudents;
  final String teacherId;
  final Teacher teacher;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClassItem({
    required this.id,
    required this.name,
    required this.courseId,
    required this.course,
    required this.startDate,
    required this.endDate,
    required this.maxStudents,
    required this.teacherId,
    required this.teacher,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClassItem.fromJson(Map<String, dynamic> json) =>
      _$ClassItemFromJson(json);

  Map<String, dynamic> toJson() => _$ClassItemToJson(this);
}

@JsonSerializable()
class Course {
  final String id;
  final String name;

  Course({required this.id, required this.name});

  factory Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);

  Map<String, dynamic> toJson() => _$CourseToJson(this);
}

@JsonSerializable()
class Teacher {
  final String id;
  final String name;

  Teacher({required this.id, required this.name});

  factory Teacher.fromJson(Map<String, dynamic> json) =>
      _$TeacherFromJson(json);

  Map<String, dynamic> toJson() => _$TeacherToJson(this);
}

// @JsonSerializable()
// class Meta {
//   final int total;
//   final int page;
//   final int limit;
//   final int totalPages;
//
//   Meta({
//     required this.total,
//     required this.page,
//     required this.limit,
//     required this.totalPages,
//   });
//
//   factory Meta.fromJson(Map<String, dynamic> json) => _$MetaFromJson(json);
//
//   Map<String, dynamic> toJson() => _$MetaToJson(this);
// }
