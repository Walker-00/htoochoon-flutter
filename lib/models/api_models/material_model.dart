// Course material (learning file attached to a class).
//
// Hand-written (no json_serializable) so it needs no build_runner step — the
// backend payload is small and stable. Mirrors the NestJS `Material` model.

class MaterialUploader {
  final String? id;
  final String name;
  final String? avatar;

  MaterialUploader({this.id, required this.name, this.avatar});

  factory MaterialUploader.fromJson(Map<String, dynamic> json) =>
      MaterialUploader(
        id: json['id'] as String?,
        name: (json['name'] ?? '') as String,
        avatar: json['avatar'] as String?,
      );
}

class CourseMaterial {
  final String id;
  final String classId;
  final String? title;
  final String fileName;
  final String fileUrl; // relative, e.g. /uploads/materials/123.pdf
  final String fileType; // MIME
  final int? fileSize; // bytes
  final DateTime? createdAt;
  final MaterialUploader? uploadedBy;

  CourseMaterial({
    required this.id,
    required this.classId,
    this.title,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    this.fileSize,
    this.createdAt,
    this.uploadedBy,
  });

  factory CourseMaterial.fromJson(Map<String, dynamic> json) => CourseMaterial(
        id: json['id'] as String,
        classId: (json['classId'] ?? '') as String,
        title: json['title'] as String?,
        fileName: (json['fileName'] ?? '') as String,
        fileUrl: (json['fileUrl'] ?? '') as String,
        fileType: (json['fileType'] ?? '') as String,
        fileSize: json['fileSize'] is int
            ? json['fileSize'] as int
            : int.tryParse('${json['fileSize']}'),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
        uploadedBy: json['uploadedBy'] != null
            ? MaterialUploader.fromJson(
                json['uploadedBy'] as Map<String, dynamic>)
            : null,
      );

  /// Display name preference: teacher title → original filename.
  String get displayName =>
      (title != null && title!.trim().isNotEmpty) ? title!.trim() : fileName;

  bool get isImage => fileType.startsWith('image/');
  bool get isVideo => fileType.startsWith('video/');
  bool get isAudio => fileType.startsWith('audio/');
  bool get isPdf => fileType == 'application/pdf';

  /// Human-readable size, e.g. "2.4 MB".
  String get readableSize {
    final s = fileSize ?? 0;
    if (s <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double v = s.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
  }
}
