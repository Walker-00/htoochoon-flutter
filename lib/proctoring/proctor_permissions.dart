import 'package:permission_handler/permission_handler.dart';

/// Result of requesting the exam proctoring permissions.
class ProctorPermissions {
  final bool camera;
  final bool microphone;
  const ProctorPermissions({required this.camera, required this.microphone});

  bool get anyGranted => camera || microphone;
}

/// Requests camera + microphone for proctoring. Both are requested together so
/// the student sees a single setup step.
Future<ProctorPermissions> requestProctorPermissions() async {
  final statuses = await [Permission.camera, Permission.microphone].request();
  return ProctorPermissions(
    camera: statuses[Permission.camera]?.isGranted ?? false,
    microphone: statuses[Permission.microphone]?.isGranted ?? false,
  );
}
