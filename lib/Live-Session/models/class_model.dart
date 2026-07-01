import 'user_model.dart';
import 'live_session_model.dart';

// class ClassModel {
//   final String id;
//   final String name;
//   final String courseId;
//   final DateTime startDate;
//   final DateTime endDate;
//   final List<UserModel> members;
//   final List<LiveSessionModel> liveSessions;
//
//   ClassModel({
//     required this.id,
//     required this.name,
//     required this.courseId,
//     required this.startDate,
//     required this.endDate,
//     required this.members,
//     required this.liveSessions,
//   });
//
//   // This allows you to create a model from your Backend JSON
//   factory ClassModel.fromJson(Map<String, dynamic> json) {
//     return ClassModel(
//       id: json['id'] ?? '',
//       name: json['name'] ?? '',
//       courseId: json['courseId'] ?? '',
//       startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toString()),
//       endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toString()),
//       members: (json['members'] as List? ?? [])
//           .map((m) => UserModel.fromJson(m['user'] ?? m))
//           .toList(),
//       liveSessions: (json['liveSessions'] as List? ?? [])
//           .map((s) => LiveSessionModel.fromJson(s))
//           .toList(),
//     );
//   }
// }
