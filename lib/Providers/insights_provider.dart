import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log/app_logger.dart';

class AtRiskStudent {
  final String studentId;
  final String name;
  final String? avatar;
  final double riskScore;
  final String level; // red | yellow | green
  final double avgScore;
  final int graded;
  final int totalAssessments;
  final List<String> reasons;

  AtRiskStudent({
    required this.studentId,
    required this.name,
    this.avatar,
    required this.riskScore,
    required this.level,
    required this.avgScore,
    required this.graded,
    required this.totalAssessments,
    required this.reasons,
  });

  factory AtRiskStudent.fromJson(Map<String, dynamic> j) => AtRiskStudent(
        studentId: '${j['studentId']}',
        name: (j['name'] as String?) ?? 'Student',
        avatar: j['avatar'] as String?,
        riskScore: (j['riskScore'] as num?)?.toDouble() ?? 0,
        level: (j['level'] as String?) ?? 'green',
        avgScore: (j['avgScore'] as num?)?.toDouble() ?? 0,
        graded: (j['graded'] as num?)?.toInt() ?? 0,
        totalAssessments: (j['totalAssessments'] as num?)?.toInt() ?? 0,
        reasons: ((j['reasons'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

class EngagementData {
  final int present;
  final int late;
  final int absent;
  final List<MapEntry<String, double>> dailyMinutes; // day -> minutes
  final List<MapEntry<String, double>> examScores; // title -> score

  EngagementData({
    required this.present,
    required this.late,
    required this.absent,
    required this.dailyMinutes,
    required this.examScores,
  });

  factory EngagementData.fromJson(Map<String, dynamic> j) {
    final att = (j['attendance'] as Map?) ?? {};
    final daily = ((j['dailyMinutes'] as List?) ?? []).map((e) {
      final m = Map<String, dynamic>.from(e);
      return MapEntry('${m['day']}', (m['minutes'] as num?)?.toDouble() ?? 0);
    }).toList();
    final exams = ((j['examScores'] as List?) ?? []).map((e) {
      final m = Map<String, dynamic>.from(e);
      return MapEntry('${m['title']}', (m['score'] as num?)?.toDouble() ?? 0);
    }).toList();
    return EngagementData(
      present: (att['present'] as num?)?.toInt() ?? 0,
      late: (att['late'] as num?)?.toInt() ?? 0,
      absent: (att['absent'] as num?)?.toInt() ?? 0,
      dailyMinutes: daily,
      examScores: exams,
    );
  }

  int get totalSessions => present + late + absent;
}

/// At-risk flags, engagement timeseries, and attendance export.
class InsightsProvider extends ChangeNotifier {
  final Dio _dio;
  InsightsProvider(this._dio);

  final _log = const AppLog('InsightsProvider');

  List<AtRiskStudent>? atRisk;
  bool loadingAtRisk = false;
  Object? atRiskError;

  EngagementData? engagement;
  bool loadingEngagement = false;
  Object? engagementError;

  Future<void> loadAtRisk(String courseId) async {
    loadingAtRisk = true;
    atRiskError = null;
    notifyListeners();
    try {
      final res = await _dio.get('/analytics/at-risk/$courseId');
      final list = (res.data['data'] as List?) ?? [];
      atRisk = list
          .map((e) => AtRiskStudent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      atRiskError = e;
      _log.w('loadAtRisk failed', e);
    } finally {
      loadingAtRisk = false;
      notifyListeners();
    }
  }

  Future<void> loadEngagement(String studentId) async {
    loadingEngagement = true;
    engagementError = null;
    notifyListeners();
    try {
      final res = await _dio.get('/analytics/engagement/$studentId');
      engagement = EngagementData.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      engagementError = e;
      _log.w('loadEngagement failed', e);
    } finally {
      loadingEngagement = false;
      notifyListeners();
    }
  }

  /// Download the attendance CSV for a session and open the share sheet.
  /// Returns true on success.
  Future<bool> exportAttendanceCsv(String liveSessionId, {String? label}) async {
    try {
      final res = await _dio.get<String>(
        '/attendance/export',
        queryParameters: {'live_session_id': liveSessionId},
        options: Options(responseType: ResponseType.plain),
      );
      final csv = res.data ?? '';
      final dir = await getTemporaryDirectory();
      final safe = (label ?? liveSessionId).replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
      final file = File('${dir.path}/attendance_$safe.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Attendance export');
      return true;
    } catch (e) {
      _log.e('exportAttendanceCsv failed', e);
      return false;
    }
  }
}
