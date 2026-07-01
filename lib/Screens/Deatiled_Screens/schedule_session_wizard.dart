import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/live_sessions_provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
import 'package:htoochoon_flutter/models/api_models/session_schedule_model.dart';
import 'package:htoochoon_flutter/widgets/lms_dialog.dart';

/// Simplified 3-step scheduler: When (time + duration) → Repeat (auto toggle) →
/// Preview & Publish. Title is auto-generated from the class + date (editable).
class ScheduleSessionWizard extends StatefulWidget {
  final String classId;
  final String orgId;
  final String hostId;
  final String className;
  const ScheduleSessionWizard({
    super.key,
    required this.classId,
    required this.orgId,
    required this.hostId,
    this.className = 'Class',
  });

  /// Returns true if a session/series was created.
  static Future<bool> show(
    BuildContext context, {
    required String classId,
    required String orgId,
    required String hostId,
    String className = 'Class',
  }) async {
    final created = await showLMSDialog<bool>(
      context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape:
            const RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusXl),
        clipBehavior: Clip.antiAlias,
        child: ScheduleSessionWizard(
          classId: classId,
          orgId: orgId,
          hostId: hostId,
          className: className,
        ),
      ),
    );
    return created ?? false;
  }

  @override
  State<ScheduleSessionWizard> createState() => _ScheduleSessionWizardState();
}

class _ScheduleSessionWizardState extends State<ScheduleSessionWizard> {
  int _step = 0; // 0 When · 1 Repeat · 2 Preview
  bool _submitting = false;

  final _titleCtrl = TextEditingController();
  DateTime? _start;
  int _durationMin = 60;
  bool _customDuration = false;
  final _customDurCtrl = TextEditingController(text: '60');

  bool _autoCreate = false; // "Create automatically" → recurring series
  final _cfg = RecurrenceConfig(freq: Freq.weekly);

  static const _timezone = 'Asia/Yangon';
  final _fmtFull = DateFormat('EEE, MMM d • h:mm a');
  final _fmtDay = DateFormat('EEE, MMM d');
  final _fmtTime = DateFormat('h:mm a');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customDurCtrl.dispose();
    super.dispose();
  }

  DateTime? get _end => _start?.add(Duration(minutes: _durationMin));

  String _autoTitle() =>
      '${widget.className} · ${_fmtDay.format(_start ?? DateTime.now())}';

  String _effectiveTitle() => _titleCtrl.text.trim().isEmpty
      ? _autoTitle()
      : _titleCtrl.text.trim();

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String? _validate() {
    if (_start == null) return 'Please pick a start time.';
    if (_durationMin <= 0) return 'Duration must be at least 1 minute.';
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_start!
        .isBefore(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))) {
      return 'Sessions must be scheduled for a future date, not today.';
    }
    return null;
  }

  List<DateTime> _occurrences() {
    if (_start == null) return const [];
    return _autoCreate ? _cfg.expand(_start!) : [_start!];
  }

  Future<void> _submit() async {
    final err = _validate();
    final messenger = ScaffoldMessenger.of(context);
    if (err != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _submitting = true);
    final prov = context.read<LiveSessionProvider>();

    bool ok;
    if (_autoCreate) {
      ok = await prov.createSeries(SeriesRequest(
        topic: _effectiveTitle(),
        courseId: widget.classId, // carries the courseId
        hostId: widget.hostId,
        timezone: _timezone,
        rrule: _cfg.toRRule(_start!)!,
        startTime: _start!.toUtc().toIso8601String(),
        durationMin: _durationMin,
      ));
    } else {
      final res = await prov.createSession(LiveSessionRequest(
        topic: _effectiveTitle(),
        courseId: widget.classId, // carries the courseId
        hostId: widget.hostId,
        startTime: _start!.toUtc().toIso8601String(),
        endTime: _end!.toUtc().toIso8601String(),
        status: LiveSessionStatus.scheduled,
      ));
      ok = res != null;
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      final e = prov.error ?? '';
      final msg = (e.contains('403') ||
              e.contains('Forbidden') ||
              e.contains('permission'))
          ? 'The designated host does not have permission to host sessions here. 💢'
          : (e.isNotEmpty ? e : 'Failed to schedule session. Please try again.');
      messenger.showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
    }
  }

  bool get _canAdvance {
    if (_step == 0) return _start != null && _durationMin > 0;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['When', 'Repeat', 'Preview'];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Branded header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.peacockTeal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_available_outlined,
                      color: AppTheme.peacockTeal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule Session',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.getTextPrimary(context))),
                      Text('${_step + 1} of 3 · ${titles[_step]}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getTextSecondary(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: _buildStep(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => _step == 0
                          ? Navigator.pop(context, false)
                          : setState(() => _step--),
                  child: Text(_step == 0 ? 'Cancel' : 'Back'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _submitting || !_canAdvance
                      ? null
                      : () {
                          if (_step < 2) {
                            setState(() => _step++);
                          } else {
                            _submit();
                          }
                        },
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_step < 2 ? 'Next' : 'Publish'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _stepWhen();
      case 1:
        return _stepRepeat();
      default:
        return _stepPreview();
    }
  }

  // ── Step 1: When (start + duration) ──────────────────────────────────────
  Widget _stepWhen() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text('When should it start?',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text(_start == null ? 'Pick start time' : _fmtFull.format(_start!)),
            onPressed: () async {
              final picked = await _pickDateTime(
                  DateTime.now().add(const Duration(days: 1, minutes: 15)));
              if (picked != null) setState(() => _start = picked);
            },
          ),
          const SizedBox(height: 16),
          Text('How long?',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _customDuration ? -1 : _durationMin,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 minutes')),
              DropdownMenuItem(value: 60, child: Text('1 hour')),
              DropdownMenuItem(value: 90, child: Text('1.5 hours')),
              DropdownMenuItem(value: 120, child: Text('2 hours')),
              DropdownMenuItem(value: -1, child: Text('Custom…')),
            ],
            onChanged: (v) => setState(() {
              if (v == -1) {
                _customDuration = true;
                _durationMin = int.tryParse(_customDurCtrl.text) ?? 60;
              } else {
                _customDuration = false;
                _durationMin = v!;
              }
            }),
          ),
          if (_customDuration) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customDurCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) =>
                  setState(() => _durationMin = int.tryParse(v) ?? _durationMin),
            ),
          ],
          if (_start != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Ends at ${_fmtTime.format(_end!)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      );

  // ── Step 2: Repeat (auto toggle + recurrence) ────────────────────────────
  Widget _stepRepeat() {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Create automatically',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Repeat on a schedule instead of a single date'),
          value: _autoCreate,
          onChanged: (v) => setState(() {
            _autoCreate = v;
            if (v && _cfg.freq == Freq.none) _cfg.freq = Freq.weekly;
          }),
        ),
        if (!_autoCreate)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'One session on ${_start == null ? '—' : _fmtFull.format(_start!)}.',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
        if (_autoCreate) ...[
          const SizedBox(height: 8),
          SegmentedButton<Freq>(
            segments: const [
              ButtonSegment(value: Freq.daily, label: Text('Daily')),
              ButtonSegment(value: Freq.weekly, label: Text('Weekly')),
              ButtonSegment(value: Freq.monthly, label: Text('Monthly')),
            ],
            selected: {_cfg.freq == Freq.none ? Freq.weekly : _cfg.freq},
            onSelectionChanged: (s) => setState(() => _cfg.freq = s.first),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Every'),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _cfg.interval > 1
                    ? () => setState(() => _cfg.interval--)
                    : null,
              ),
              Text('${_cfg.interval}'),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _cfg.interval++),
              ),
              Text(_cfg.freq == Freq.daily
                  ? 'day(s)'
                  : _cfg.freq == Freq.weekly
                      ? 'week(s)'
                      : 'month(s)'),
            ],
          ),
          if (_cfg.freq == Freq.weekly) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final iso = i + 1;
                final sel = _cfg.weekdays.contains(iso);
                return FilterChip(
                  label: Text(dayLabels[i]),
                  selected: sel,
                  onSelected: (v) => setState(() =>
                      v ? _cfg.weekdays.add(iso) : _cfg.weekdays.remove(iso)),
                );
              }),
            ),
          ],
          const SizedBox(height: 12),
          const Text('Ends', style: TextStyle(fontWeight: FontWeight.w600)),
          RadioListTile<EndMode>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: EndMode.count,
            groupValue: _cfg.endMode,
            onChanged: (v) => setState(() => _cfg.endMode = v!),
            title: Row(
              children: [
                const Text('After'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: TextFormField(
                    initialValue: '${_cfg.count}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) =>
                        _cfg.count = int.tryParse(v) ?? _cfg.count,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('times'),
              ],
            ),
          ),
          RadioListTile<EndMode>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: EndMode.until,
            groupValue: _cfg.endMode,
            onChanged: (v) => setState(() => _cfg.endMode = v!),
            title: Row(
              children: [
                const Text('On date'),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _cfg.until ??
                          (_start ?? DateTime.now())
                              .add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _cfg.until = d);
                  },
                  child: Text(_cfg.until == null
                      ? 'Pick'
                      : '${_cfg.until!.month}/${_cfg.until!.day}/${_cfg.until!.year}'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Step 3: Preview & Publish ────────────────────────────────────────────
  Widget _stepPreview() {
    final err = _validate();
    final occ = _occurrences();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            labelText: 'Title (optional)',
            hintText: _autoTitle(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              occ.length == 1 ? '1 session' : '${occ.length} sessions',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text('${_durationMin}m each',
                style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ],
        ),
        const SizedBox(height: 8),
        if (err != null)
          Text(err, style: const TextStyle(color: Colors.red))
        else
          ...occ.take(50).map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record,
                        size: 8, color: AppTheme.peacockTeal),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_fmtDay.format(d))),
                    Text(_fmtTime.format(d),
                        style:
                            TextStyle(color: AppTheme.getTextSecondary(context))),
                  ],
                ),
              )),
        if (occ.length > 50)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('+ ${occ.length - 50} more…',
                style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
      ],
    );
  }
}
