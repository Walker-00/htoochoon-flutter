import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─── Generated avatar (DiceBear, no extra dependency) ────────────────────────
///
/// Deterministic identicon-style avatar rendered by DiceBear's public HTTP API.
/// The same [seed] always yields the same picture, so a user without an uploaded
/// photo still gets a stable, recognisable avatar across sessions and devices.
String generatedAvatarUrl(
  String seed, {
  String style = 'thumbs',
  int size = 200,
}) {
  final safeStyle = kAvatarStyles.contains(style) ? style : 'thumbs';
  return 'https://api.dicebear.com/9.x/$safeStyle/png'
      '?seed=${Uri.encodeComponent(seed)}&size=$size';
}

/// Styles offered in the "generated avatar" style picker.
const kAvatarStyles = <String>[
  'thumbs',
  'identicon',
  'bottts',
  'avataaars',
  'initials',
];

/// ─── Local style persistence ─────────────────────────────────────────────────
///
/// The backend has no "avatar style" field, so a user's chosen generated style
/// is remembered locally (per user id). When no uploaded photo exists we render
/// the generated avatar in this style; otherwise we fall back to 'thumbs'.
String _prefsKey(String userId) => 'avatar_style_$userId';

Future<String> getSavedAvatarStyle(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefsKey(userId));
    if (v != null && kAvatarStyles.contains(v)) return v;
  } catch (_) {}
  return 'thumbs';
}

Future<void> saveAvatarStyle(String userId, String style) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(userId), style);
  } catch (_) {}
}

/// ─── Editable avatar widget ──────────────────────────────────────────────────
///
/// Single reusable avatar control shared by the settings profile card and the
/// dedicated Personal Information screen. Tapping it opens a bottom sheet with:
///   • Upload photo        (gallery picker → preview → save)
///   • Use a generated avatar (pick a style, preview, save)
///   • Reset to default    (clears the uploaded photo → generated avatar shows)
class EditableAvatar extends StatefulWidget {
  final double size;
  final bool showEditBadge;

  const EditableAvatar({super.key, this.size = 72, this.showEditBadge = true});

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  XFile? _preview;
  String _style = 'thumbs';

  /// Set after a reset / generated-style choice so the generated avatar shows
  /// this session even if the backend silently keeps the old uploaded avatar.
  bool _forceGenerated = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      getSavedAvatarStyle(user.id).then((s) {
        if (mounted) setState(() => _style = s);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final radius = widget.size * 0.17;

    return GestureDetector(
      onTap: () => _openSheet(context, user),
      child: Stack(
        children: [
          _avatar(user, radius),
          if (widget.showEditBadge)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar(User user, double radius) {
    final size = widget.size;

    // 1. Local preview of a freshly-picked file.
    if (_preview != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: kIsWeb
            ? Image.network(_preview!.path,
                width: size, height: size, fit: BoxFit.cover)
            : Image.file(File(_preview!.path),
                width: size, height: size, fit: BoxFit.cover),
      );
    }

    // 2. Uploaded avatar from the backend.
    final remote = user.absoluteAvatarUrl;
    if (!_forceGenerated && remote != null && remote.isNotEmpty) {
      final busted =
          '$remote?t=${user.updatedAt?.millisecondsSinceEpoch ?? ''}';
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          busted,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _generated(user, radius),
        ),
      );
    }

    // 3. No uploaded photo → deterministic generated avatar.
    return _generated(user, radius);
  }

  Widget _generated(User user, double radius) {
    final size = widget.size;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: generatedAvatarUrl(
          user.id.isNotEmpty ? user.id : user.name,
          style: _style,
          size: 200,
        ),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.primary,
          child: Icon(Icons.person, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _openSheet(BuildContext context, User user) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: cs.primary),
              title: const Text('Upload photo'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUpload(user);
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_awesome, color: cs.primary),
              title: const Text('Use a generated avatar'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickStyle(user);
              },
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: cs.onSurface),
              title: const Text('Reset to default'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _resetToDefault(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(User user) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    if (mounted) {
      setState(() {
        _preview = picked;
        _forceGenerated = false;
      });
    }

    bool ok = false;
    try {
      ok = await auth.uploadProfilePicture(user.id, picked);
    } catch (e) {
      // Some backends return a body that fails to deserialize even on success.
      final s = e.toString();
      if (s.contains('type cast') || s.contains('subtype of type')) ok = true;
    }
    if (mounted) setState(() => _preview = null);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile picture updated' : 'Failed to upload image'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _pickStyle(User user) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        String temp = _style;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final cs = Theme.of(ctx).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a style',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: kAvatarStyles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final style = kAvatarStyles[i];
                          final selected = style == temp;
                          return GestureDetector(
                            onTap: () => setSheet(() => temp = style),
                            child: Container(
                              width: 72,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected ? cs.primary : cs.outline,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: CachedNetworkImage(
                                  imageUrl: generatedAvatarUrl(
                                    user.id.isNotEmpty ? user.id : user.name,
                                    style: style,
                                    size: 120,
                                  ),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: cs.surfaceContainerHighest,
                                  ),
                                  errorWidget: (_, __, ___) =>
                                      Icon(Icons.person, color: cs.primary),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          minimumSize: const Size.fromHeight(44),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetCtx, temp),
                        child: const Text(
                          'Use this avatar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (chosen == null) return;
    await saveAvatarStyle(user.id, chosen);
    if (mounted) setState(() => _style = chosen);
    // Clear any uploaded photo so the generated avatar becomes the active one.
    await _clearUploadedAvatar(user);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generated avatar applied'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _resetToDefault(User user) async {
    final messenger = ScaffoldMessenger.of(context);
    await _clearUploadedAvatar(user);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Reset to default avatar')),
    );
  }

  Future<void> _clearUploadedAvatar(User user) async {
    if (mounted) setState(() => _forceGenerated = true);
    try {
      await context.read<AuthProvider>().updateUser(user.id, {'avatar': null});
    } catch (_) {
      // If the backend ignores/rejects a null avatar the UI still falls back to
      // the generated avatar locally, which is acceptable.
    }
  }
}
