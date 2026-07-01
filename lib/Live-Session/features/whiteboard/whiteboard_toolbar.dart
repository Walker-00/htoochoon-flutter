import 'package:flutter/material.dart';
import 'whiteboard_models.dart';

class WhiteboardToolbar extends StatelessWidget {
  final WbTool activeTool;
  final Color activeColor;
  final double strokeWidth;
  final WbPermissions permissions;
  final bool isTeacher;
  final bool studentsCanDraw;
  final int undoCount;
  final int redoCount;
  final ValueChanged<WbTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onExport;
  final ValueChanged<bool>? onToggleStudentDraw;
  final VoidCallback? onManagePermissions;
  final VoidCallback onClose;

  const WhiteboardToolbar({
    super.key,
    required this.activeTool,
    required this.activeColor,
    required this.strokeWidth,
    required this.permissions,
    required this.isTeacher,
    required this.studentsCanDraw,
    required this.undoCount,
    required this.redoCount,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onExport,
    this.onToggleStudentDraw,
    this.onManagePermissions,
    required this.onClose,
  });

  static const _colors = [
    Colors.black,
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: isWide ? _buildWideLayout(cs) : _buildNarrowLayout(cs),
      ),
    );
  }

  Widget _buildWideLayout(ColorScheme cs) {
    return Row(
      children: [
        _closeBtn(cs),
        const SizedBox(width: 4),
        _divider(cs),
        ..._toolButtons(cs),
        _divider(cs),
        ..._colorDots(cs),
        _divider(cs),
        _strokeSlider(cs),
        _divider(cs),
        _actionBtn(Icons.undo, undoCount > 0 ? onUndo : null, cs, 'Undo'),
        _actionBtn(Icons.redo, redoCount > 0 ? onRedo : null, cs, 'Redo'),
        if (permissions.canClear) ...[
          _divider(cs),
          _actionBtn(Icons.delete_outline, onClear, cs, 'Clear'),
        ],
        _actionBtn(Icons.save_alt, onExport, cs, 'Export'),
        if (isTeacher && onToggleStudentDraw != null) ...[
          _divider(cs),
          _toggleStudentBtn(cs),
          if (onManagePermissions != null)
            _actionBtn(Icons.settings, onManagePermissions, cs, 'Manage permissions'),
        ],
        const Spacer(),
      ],
    );
  }

  Widget _buildNarrowLayout(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _closeBtn(cs),
              ..._toolButtons(cs),
              _divider(cs),
              _actionBtn(Icons.undo, undoCount > 0 ? onUndo : null, cs, 'Undo'),
              _actionBtn(Icons.redo, redoCount > 0 ? onRedo : null, cs, 'Redo'),
              if (permissions.canClear)
                _actionBtn(Icons.delete_outline, onClear, cs, 'Clear'),
              _actionBtn(Icons.save_alt, onExport, cs, 'Export'),
              if (isTeacher && onToggleStudentDraw != null) ...[
                _toggleStudentBtn(cs),
                if (onManagePermissions != null)
                  _actionBtn(Icons.settings, onManagePermissions, cs, 'Manage permissions'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._colorDots(cs),
              const SizedBox(width: 8),
              SizedBox(width: 120, child: _strokeSliderRaw(cs)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _closeBtn(ColorScheme cs) {
    return IconButton(
      icon: const Icon(Icons.close, size: 20),
      tooltip: 'Close whiteboard',
      onPressed: onClose,
      style: IconButton.styleFrom(
        foregroundColor: cs.onSurface,
      ),
    );
  }

  List<Widget> _toolButtons(ColorScheme cs) {
    final tools = <(WbTool, IconData, String)>[
      (WbTool.select, Icons.pan_tool_alt, 'Pan / Select'),
      (WbTool.pen, Icons.edit, 'Pen'),
      (WbTool.eraser, Icons.auto_fix_normal, 'Eraser'),
      (WbTool.line, Icons.horizontal_rule, 'Line'),
      (WbTool.rect, Icons.crop_square, 'Rectangle'),
      (WbTool.circle, Icons.circle_outlined, 'Circle'),
      (WbTool.arrow, Icons.arrow_right_alt, 'Arrow'),
      (WbTool.text, Icons.text_fields, 'Text'),
    ];

    final canUse = permissions.canDraw;

    return tools.map((t) {
      final isSelect = t.$1 == WbTool.select;
      final isEraser = t.$1 == WbTool.eraser;
      final enabled = isSelect ? true : (isEraser ? permissions.canErase : canUse);
      final isActive = activeTool == t.$1;
      return Tooltip(
        message: t.$3,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? () => onToolChanged(t.$1) : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? cs.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              t.$2,
              size: 18,
              color: enabled
                  ? (isActive ? cs.onPrimaryContainer : cs.onSurface)
                  : cs.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _colorDots(ColorScheme cs) {
    return _colors.map((c) {
      final isActive = activeColor.value == c.value;
      return GestureDetector(
        onTap: permissions.canDraw ? () => onColorChanged(c) : null,
        child: Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? cs.primary : cs.outlineVariant,
              width: isActive ? 2.5 : 1,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _strokeSlider(ColorScheme cs) {
    return SizedBox(width: 100, child: _strokeSliderRaw(cs));
  }

  Widget _strokeSliderRaw(ColorScheme cs) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.outlineVariant,
        thumbColor: cs.primary,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        value: strokeWidth,
        min: 1,
        max: 20,
        onChanged: permissions.canDraw ? onStrokeChanged : null,
      ),
    );
  }

  Widget _actionBtn(IconData icon, VoidCallback? onPressed, ColorScheme cs, String tip) {
    return Tooltip(
      message: tip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: onPressed != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _toggleStudentBtn(ColorScheme cs) {
    return Tooltip(
      message: studentsCanDraw ? 'Lock student drawing' : 'Allow student drawing',
      child: IconButton(
        icon: Icon(
          studentsCanDraw ? Icons.lock_open : Icons.lock,
          size: 20,
          color: studentsCanDraw ? cs.primary : cs.error,
        ),
        onPressed: () => onToggleStudentDraw?.call(!studentsCanDraw),
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: cs.outlineVariant,
    );
  }
}
