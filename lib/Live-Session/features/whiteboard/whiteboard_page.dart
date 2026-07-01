import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/socket_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'dart:io';
import 'whiteboard_models.dart';
import 'whiteboard_painter.dart';
import 'whiteboard_toolbar.dart';

class WhiteboardPage extends StatefulWidget {
  final String roomId;
  final String userId;
  final String role;
  final SocketService socketService;

  /// Initial "students can draw" permission (chosen in the meeting setup dialog).
  final bool initialStudentsCanDraw;

  /// When false, strokes stay local (no socket broadcast) — the teacher's board
  /// is private. When true, every action is synced to the room in real time.
  final bool liveSync;

  /// Whether to pop the teacher permission dialog on open. Skipped when the
  /// permissions were already chosen before launching (e.g. detached window).
  final bool showSetupOnStart;

  /// How to close the board. Null → pop the current route. A detached OS window
  /// passes a callback that closes the window instead.
  final VoidCallback? onClose;

  const WhiteboardPage({
    super.key,
    required this.roomId,
    required this.userId,
    required this.role,
    required this.socketService,
    this.initialStudentsCanDraw = false,
    this.liveSync = true,
    this.showSetupOnStart = true,
    this.onClose,
  });

  @override
  State<WhiteboardPage> createState() => _WhiteboardPageState();
}

class _WhiteboardPageState extends State<WhiteboardPage> {
  final List<WbElement> _elements = [];
  final List<WbElement> _undoStack = [];
  WbElement? _activeElement;
  WbTool _tool = WbTool.pen;
  Color _color = Colors.black;
  double _strokeWidth = 3.0;
  late bool _studentsCanDraw = widget.initialStudentsCanDraw;
  int _idCounter = 0;

  /// Broadcast a whiteboard event to the room — no-op when [liveSync] is off so
  /// the board stays local to the teacher.
  void _sync(String event, [Map<String, dynamic>? data]) {
    if (!widget.liveSync) return;
    widget.socketService.emit(event, data);
  }

  final TransformationController _transformCtrl = TransformationController();
  final GlobalKey _canvasKey = GlobalKey();

  // Canvas dimensions for the drawing area (virtual size for infinite feel)
  static const double _canvasSize = 8000;

  bool get _isTeacher {
    final r = widget.role.toUpperCase();
    return r == 'TEACHER' || r == 'ADMIN' || r == 'STAFF';
  }

  WbPermissions get _permissions {
    if (_isTeacher) return WbPermissions.teacher;
    return _studentsCanDraw
        ? WbPermissions.studentEnabled
        : WbPermissions.studentDisabled;
  }

  String _nextId() => '${widget.userId}_${_idCounter++}';

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
    _requestBoardState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _transformCtrl.value = Matrix4.identity()
        ..translate(
          -_canvasSize / 2 + size.width / 2,
          -_canvasSize / 2 + size.height / 2,
        );
      if (_isTeacher && widget.showSetupOnStart) {
        _showPermissionSetupDialog(isInitial: true);
      }
    });
  }

  void _showPermissionSetupDialog({bool isInitial = false}) {
    showDialog(
      context: context,
      barrierDismissible: !isInitial,
      builder: (ctx) {
        bool allow = _studentsCanDraw;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            icon: Icon(Icons.draw_outlined,
                color: Theme.of(ctx).colorScheme.primary),
            title: const Text('Whiteboard Permissions'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Configure who can draw on the whiteboard. '
                  'You can change this anytime from the toolbar.',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Allow students to draw'),
                  subtitle: Text(
                    allow
                        ? 'Students can draw, erase, and annotate'
                        : 'Only teachers and staff can draw',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: allow,
                  onChanged: (v) => setDialogState(() => allow = v),
                  secondary: Icon(allow ? Icons.lock_open : Icons.lock),
                ),
              ],
            ),
            actions: [
              if (!isInitial)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _toggleStudentDraw(allow);
                },
                child: Text(isInitial ? 'Start whiteboard' : 'Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setupSocketListeners() {
    widget.socketService.on('whiteboard:draw', (data) {
      if (!mounted) return;
      final el = WbElement.fromJson(Map<String, dynamic>.from(data));
      if (el.userId == widget.userId) return;
      setState(() => _elements.add(el));
    });

    widget.socketService.on('whiteboard:erase', (data) {
      if (!mounted) return;
      final id = data['id'] as String;
      setState(() => _elements.removeWhere((e) => e.id == id));
    });

    widget.socketService.on('whiteboard:clear', (_) {
      if (!mounted) return;
      setState(() {
        _elements.clear();
        _undoStack.clear();
      });
    });

    widget.socketService.on('whiteboard:undo', (data) {
      if (!mounted) return;
      final id = data['id'] as String;
      final uid = data['userId'] as String;
      if (uid == widget.userId) return;
      setState(() => _elements.removeWhere((e) => e.id == id));
    });

    widget.socketService.on('whiteboard:permission', (data) {
      if (!mounted) return;
      setState(() => _studentsCanDraw = data['studentsCanDraw'] == true);
    });

    widget.socketService.on('whiteboard:state', (data) {
      if (!mounted) return;
      final elems = (data['elements'] as List?)
              ?.map((e) => WbElement.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [];
      setState(() {
        _elements.clear();
        _elements.addAll(elems);
        _studentsCanDraw = data['studentsCanDraw'] == true;
      });
    });
  }

  void _requestBoardState() {
    _sync('whiteboard:join', {'roomId': widget.roomId});
  }

  @override
  void dispose() {
    widget.socketService.off('whiteboard:draw');
    widget.socketService.off('whiteboard:erase');
    widget.socketService.off('whiteboard:clear');
    widget.socketService.off('whiteboard:undo');
    widget.socketService.off('whiteboard:permission');
    widget.socketService.off('whiteboard:state');
    _sync('whiteboard:leave', {'roomId': widget.roomId});
    _transformCtrl.dispose();
    super.dispose();
  }

  bool get _isDrawing {
    if (_tool == WbTool.select) return false;
    if (_tool == WbTool.eraser) return _permissions.canErase;
    return _permissions.canDraw;
  }

  // --- Drawing Gesture Handling ---

  void _handlePointerDown(PointerDownEvent e) {
    _onPanStart(DragStartDetails(localPosition: e.localPosition));
  }

  void _handlePointerMove(PointerMoveEvent e) {
    _onPanUpdate(DragUpdateDetails(
      localPosition: e.localPosition,
      globalPosition: e.position,
    ));
  }

  void _handlePointerUp(PointerUpEvent e) {
    _onPanEnd(DragEndDetails());
  }

  Offset _toCanvas(Offset screenPos) {
    final matrix = _transformCtrl.value.clone()..invert();
    final v = matrix.transform3(Vector3(screenPos.dx, screenPos.dy, 0));
    return Offset(v.x, v.y);
  }

  void _onPanStart(DragStartDetails d) {
    if (!_permissions.canDraw && _tool != WbTool.eraser) return;
    if (_tool == WbTool.eraser && !_permissions.canErase) return;

    final pos = _toCanvas(d.localPosition);

    if (_tool == WbTool.text) {
      _showTextDialog(pos);
      return;
    }

    final el = WbElement(
      id: _nextId(),
      type: _tool.name,
      userId: widget.userId,
      color: _color,
      strokeWidth: _strokeWidth,
      points: (_tool == WbTool.pen || _tool == WbTool.eraser) ? [pos] : [],
      start: (_tool != WbTool.pen && _tool != WbTool.eraser) ? pos : null,
      end: (_tool != WbTool.pen && _tool != WbTool.eraser) ? pos : null,
    );
    setState(() => _activeElement = el);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_activeElement == null) return;
    final pos = _toCanvas(d.localPosition);

    setState(() {
      if (_activeElement!.type == 'pen' || _activeElement!.type == 'eraser') {
        _activeElement = _activeElement!.copyWith(
          points: [..._activeElement!.points, pos],
        );
      } else {
        _activeElement = _activeElement!.copyWith(end: pos);
      }
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_activeElement == null) return;

    if (_activeElement!.type == 'eraser') {
      _eraseNear(_activeElement!.points);
      setState(() => _activeElement = null);
      return;
    }

    final el = _activeElement!;
    setState(() {
      _elements.add(el);
      _undoStack.clear();
      _activeElement = null;
    });

    _sync('whiteboard:draw', {
      'roomId': widget.roomId,
      ...el.toJson(),
    });
  }

  void _eraseNear(List<Offset> eraserPath) {
    const threshold = 15.0;
    final toRemove = <WbElement>[];

    for (final el in _elements) {
      bool hit = false;
      for (final ep in eraserPath) {
        if (el.type == 'pen' || el.type == 'eraser') {
          for (final p in el.points) {
            if ((p - ep).distance < threshold + el.strokeWidth) {
              hit = true;
              break;
            }
          }
        } else if (el.start != null && el.end != null) {
          final rect = Rect.fromPoints(el.start!, el.end!).inflate(threshold);
          if (rect.contains(ep)) hit = true;
        } else if (el.start != null) {
          if ((el.start! - ep).distance < threshold + 20) hit = true;
        }
        if (hit) break;
      }
      if (hit) toRemove.add(el);
    }

    for (final el in toRemove) {
      setState(() => _elements.remove(el));
      _sync('whiteboard:erase', {
        'roomId': widget.roomId,
        'id': el.id,
      });
    }
  }

  void _showTextDialog(Offset pos) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add text'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter text...'),
          onSubmitted: (_) => Navigator.pop(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (ctrl.text.trim().isEmpty) return;
              final el = WbElement(
                id: _nextId(),
                type: 'text',
                userId: widget.userId,
                color: _color,
                strokeWidth: _strokeWidth,
                start: pos,
                text: ctrl.text.trim(),
              );
              setState(() {
                _elements.add(el);
                _undoStack.clear();
              });
              _sync('whiteboard:draw', {
                'roomId': widget.roomId,
                ...el.toJson(),
              });
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _undo() {
    if (_elements.isEmpty) return;
    final myElements =
        _elements.where((e) => e.userId == widget.userId).toList();
    if (myElements.isEmpty) return;

    final last = myElements.last;
    setState(() {
      _elements.remove(last);
      _undoStack.add(last);
    });
    _sync('whiteboard:undo', {
      'roomId': widget.roomId,
      'id': last.id,
      'userId': widget.userId,
    });
  }

  void _redo() {
    if (_undoStack.isEmpty) return;
    final el = _undoStack.removeLast();
    setState(() => _elements.add(el));
    _sync('whiteboard:draw', {
      'roomId': widget.roomId,
      ...el.toJson(),
    });
  }

  void _clear() {
    if (!_permissions.canClear) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear whiteboard?'),
        content: const Text('This will remove all drawings for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _elements.clear();
                _undoStack.clear();
              });
              _sync('whiteboard:clear', {
                'roomId': widget.roomId,
              });
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _toggleStudentDraw(bool allow) {
    setState(() => _studentsCanDraw = allow);
    _sync('whiteboard:permission', {
      'roomId': widget.roomId,
      'studentsCanDraw': allow,
    });
  }

  Future<void> _export() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // White background
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1920, 1080),
        Paint()..color = Colors.white,
      );

      final painter = WhiteboardPainter(elements: _elements);
      painter.paint(canvas, const Size(1920, 1080));

      final picture = recorder.endRecording();
      final img = await picture.toImage(1920, 1080);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) throw Exception('Failed to encode image');

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/whiteboard_$ts.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // Copy to Downloads on desktop
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        String? dlPath;
        if (Platform.isLinux || Platform.isMacOS) {
          dlPath = '${Platform.environment['HOME']}/Downloads/whiteboard_$ts.png';
        } else if (Platform.isWindows) {
          dlPath = '${Platform.environment['USERPROFILE']}\\Downloads\\whiteboard_$ts.png';
        }
        if (dlPath != null) await file.copy(dlPath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Whiteboard exported as PNG')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Status bar
          _buildStatusBar(cs),
          // Canvas area — drawing tools use Listener (raw pointer) so they
          // don't fight InteractiveViewer's pan gesture recogniser.
          Expanded(
            child: Listener(
              onPointerDown: _isDrawing ? _handlePointerDown : null,
              onPointerMove: _isDrawing ? _handlePointerMove : null,
              onPointerUp: _isDrawing ? _handlePointerUp : null,
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: 0.1,
                maxScale: 5.0,
                constrained: false,
                panEnabled: !_isDrawing,
                scaleEnabled: true,
                child: MouseRegion(
                  cursor: _getCursor(),
                  child: RepaintBoundary(
                    key: _canvasKey,
                    child: CustomPaint(
                      size: const Size(_canvasSize, _canvasSize),
                      painter: WhiteboardPainter(
                        elements: _elements,
                        activeElement: _activeElement,
                        gridColor: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Toolbar
          WhiteboardToolbar(
            activeTool: _tool,
            activeColor: _color,
            strokeWidth: _strokeWidth,
            permissions: _permissions,
            isTeacher: _isTeacher,
            studentsCanDraw: _studentsCanDraw,
            undoCount: _elements
                .where((e) => e.userId == widget.userId)
                .length,
            redoCount: _undoStack.length,
            onToolChanged: (t) => setState(() => _tool = t),
            onColorChanged: (c) => setState(() => _color = c),
            onStrokeChanged: (w) => setState(() => _strokeWidth = w),
            onUndo: _undo,
            onRedo: _redo,
            onClear: _clear,
            onExport: _export,
            onToggleStudentDraw: _isTeacher ? _toggleStudentDraw : null,
            onManagePermissions: _isTeacher ? _showPermissionSetupDialog : null,
            onClose: widget.onClose ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.draw_outlined, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            'Whiteboard',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _permissions.canDraw
                  ? cs.primaryContainer
                  : cs.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _permissions.canDraw ? 'Can draw' : 'View only',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _permissions.canDraw
                    ? cs.onPrimaryContainer
                    : cs.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_elements.length} objects',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  MouseCursor _getCursor() {
    if (!_permissions.canDraw && _tool != WbTool.eraser) {
      return SystemMouseCursors.basic;
    }
    switch (_tool) {
      case WbTool.pen:
        return SystemMouseCursors.precise;
      case WbTool.eraser:
        return SystemMouseCursors.precise;
      case WbTool.text:
        return SystemMouseCursors.text;
      case WbTool.select:
        return SystemMouseCursors.grab;
      default:
        return SystemMouseCursors.precise;
    }
  }
}
