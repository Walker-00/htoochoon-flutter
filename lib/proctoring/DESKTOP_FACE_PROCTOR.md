# Desktop face-cam behaviour proctoring (TFLite) — integration plan

Status: **scaffolded, OFF**. `PlatformSupport.supportsDesktopFaceProctor` returns
`false` so beta builds never pull unverified native deps. Mobile (Android/iOS)
already does full ML-Kit face/behaviour proctoring; desktop currently gets
network proxy/VPN detection + lifecycle/focus proctoring. This doc is the recipe
to add **real** front-camera behaviour detection (multi-face + look-away) on
Windows / macOS / Linux.

Why it isn't just a gate flip: the mobile stack uses `google_mlkit_face_detection`
and `noise_meter`, neither of which has a desktop implementation, and `camera`
has no desktop platform packages in `pubspec.yaml`. Desktop needs its own
camera + inference pipeline.

## 1. Dependencies (`pubspec.yaml`)
```yaml
  # Desktop camera (federated; official endorsed implementations)
  camera_windows: ^0.2.6
  camera_macos: ^0.0.9      # community; or use `camera_avfoundation` patterns
  # Linux: no official plugin — use `camera_linux` (community) or a v4l2 FFI shim.
  tflite_flutter: ^0.11.0    # TF Lite C API, supports win/mac/linux
```
Run `flutter pub get`. Add the native TF Lite shared libs per OS (see
`tflite_flutter` README — `install.sh`/DLL placement under `windows/`, `macos/`,
`linux/`).

## 2. Model asset
Bundle a small face-detector `.tflite` (BlazeFace / MediaPipe face_detection_short).
```yaml
flutter:
  assets:
    - assets/models/face_detection_short_range.tflite
```
Output: N face boxes + 6 keypoints (eyes, nose, mouth, ears). Multi-face = count
> 1. Gaze (look-away) = horizontal offset of nose keypoint vs box centre, and
eye-line tilt for look-down.

## 3. Frame source
Desktop `camera` has **no `startImageStream`** (mobile-only). Use periodic
`controller.takePicture()` (~2–3 fps), decode with `package:image`, downscale to
the model input (e.g. 128×128), normalise, run inference.

## 4. New class `DesktopFaceProctor`
Mirror the public surface of `CameraFaceProctor` so `BehaviorMonitor` can use
either behind `PlatformSupport`:
```
Future<void> start();
void pause(); void resume();
Stream<BehaviorEvent> get events;   // emits multiplePerson / faceMissing /
Future<void> dispose();             //   lookingLeft/Right/Down via keypoints
```
Emit the existing `BehaviorEventType`s so scoring + the teacher timeline need no
changes. Wrap every native call in try/catch (missing model/camera/lib must
degrade to "unavailable", never crash the exam — same contract as the rest of
the proctoring stack).

## 5. Wiring
- `PlatformSupport.supportsDesktopFaceProctor` → `isDesktop` (once verified).
- `behavior_monitor.dart`: if mobile → `CameraFaceProctor`; else if
  `supportsDesktopFaceProctor` → `DesktopFaceProctor`.
- `take_assignment_screen.dart`: drop the `if (!_fullProctor)` early-return for
  desktop when `supportsDesktopFaceProctor`, show consent (no room-scan setup —
  room scan stays mobile-only), start the monitor with camera only (no audio:
  `noise_meter` has no desktop backend).

## 6. Verify ON A REAL DESKTOP (cannot be done in CI / headless)
- Camera permission prompt (macOS entitlement `com.apple.security.device.camera`;
  Windows capability; Linux v4l2 access).
- One face → clean; two faces → `MULTIPLE_PERSON`; cover camera → `FACE_MISSING`;
  look away → `LOOKING_*`.
- App-size + cold-start impact of the TF Lite lib + model.

Until §1–§6 are done and device-tested, leave `supportsDesktopFaceProctor=false`.
