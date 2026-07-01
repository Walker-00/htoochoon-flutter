import 'package:permission_handler/permission_handler.dart';

class MediaPermission {
  static Future<bool> requestCameraAndMic() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();

    return camera.isGranted && mic.isGranted;
  }

  static Future<bool> checkCameraAndMic() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;

    return camera.isGranted && mic.isGranted;
  }
}