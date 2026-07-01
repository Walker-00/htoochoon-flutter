import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api/api_service.dart';
import '../../models/api_models/program_model.dart';
import '../Deatiled_Screens/student_overview_screen.dart';

const String _kMediaBase = 'https://backend.htoochoon.com';

/// Advanced student search/filter for org admins/teachers.
/// Backed by GET /organizations/{orgId}/students/search.
class AdvancedStudentSearchScreen extends StatefulWidget {
  final String organizationId;
  const AdvancedStudentSearchScreen({super.key, required this.organizationId});

  @override
  State<AdvancedStudentSearchScreen> createState() =>
      _AdvancedStudentSearchScreenState();
}

class _AdvancedStudentSearchScreenState
    extends State<AdvancedStudentSearchScreen> {
  final _searchCtrl = TextEditingController();

  List<ProgramResponse> _programs = [];
  String? _programId;
  String? _status; // ACTIVE | PENDING | COMPLETED | DROPPED
  DateTime? _joinedFrom, _joinedTo, _enrolledFrom, _enrolledTo;
  String _sortBy = 'joinedAt'; // joinedAt | name
  String _order = 'desc'; // asc | desc

  List<Map<String, dynamic>> _results = [];
  int _total = 0;
  bool _loading = false;
  bool _loaded = false;

  static const _statusOptions = ['ACTIVE', 'PENDING', 'COMPLETED', 'DROPPED'];

  @override
  void initState() {
    super.initState();
    _loadPrograms();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrograms() async {
    try {
      final list = await context
          .read<ApiService>()
          .getPrograms(null, widget.organizationId);
      if (mounted) setState(() => _programs = list);
    } catch (_) {/* non-fatal: filter just won't list programs */}
  }

  int get _activeFilterCount =>
      (_programId != null ? 1 : 0) +
      (_status != null ? 1 : 0) +
      (_joinedFrom != null || _joinedTo != null ? 1 : 0) +
      (_enrolledFrom != null || _enrolledTo != null ? 1 : 0);

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      String? iso(DateTime? d) => d?.toUtc().toIso8601String();
      final res = await context.read<ApiService>().searchOrgStudents(
            widget.organizationId,
            search: _searchCtrl.text.trim().isEmpty
                ? null
                : _searchCtrl.text.trim(),
            programId: _programId,
            status: _status,
            joinedFrom: iso(_joinedFrom),
            joinedTo: iso(_joinedTo),
            enrolledFrom: iso(_enrolledFrom),
            enrolledTo: iso(_enrolledTo),
            sortBy: _sortBy,
            order: _order,
            limit: 100,
          );
      final map = res is Map ? res.cast<String, dynamic>() : const {};
      final students = (map['students'] as List?)
              ?.whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList() ??
          [];
      if (!mounted) return;
      setState(() {
        _results = students;
        _total = (map['total'] as num?)?.toInt() ?? students.length;
        _loading = false;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loaded = true;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _programId = null;
      _status = null;
      _joinedFrom = _joinedTo = _enrolledFrom = _enrolledTo = null;
      _sortBy = 'joinedAt';
      _order = 'desc';
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student search'),
        actions: [
          if (_activeFilterCount > 0)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search + filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Name or email…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _activeFilterCount > 0,
                  label: Text('$_activeFilterCount'),
                  child: IconButton.filledTonal(
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'Filters',
                  ),
                ),
              ],
            ),
          ),
          // Active filter chips
          if (_activeFilterCount > 0) _activeChips(cs),
          if (_loading) const LinearProgressIndicator(),
          if (_loaded && !_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$_total ${_total == 1 ? 'student' : 'students'}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            ),
          Expanded(
            child: _results.isEmpty && _loaded && !_loading
                ? _empty(cs)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _studentTile(cs, _results[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _activeChips(ColorScheme cs) {
    final chips = <Widget>[];
    void chip(String label, VoidCallback onClear) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(
          label: Text(label),
          onDeleted: onClear,
        ),
      ));
    }

    if (_programId != null) {
      ProgramResponse? prog;
      for (final p in _programs) {
        if (p.id == _programId) {
          prog = p;
          break;
        }
      }
      chip('Program: ${prog?.name ?? 'Selected'}', () {
        setState(() => _programId = null);
        _search();
      });
    }
    if (_status != null) {
      chip('Status: $_status', () {
        setState(() => _status = null);
        _search();
      });
    }
    if (_joinedFrom != null || _joinedTo != null) {
      chip('Joined ${_rangeLabel(_joinedFrom, _joinedTo)}', () {
        setState(() => _joinedFrom = _joinedTo = null);
        _search();
      });
    }
    if (_enrolledFrom != null || _enrolledTo != null) {
      chip('Enrolled ${_rangeLabel(_enrolledFrom, _enrolledTo)}', () {
        setState(() => _enrolledFrom = _enrolledTo = null);
        _search();
      });
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
  }

  String _rangeLabel(DateTime? from, DateTime? to) {
    final f = from == null ? '…' : DateFormat('d MMM').format(from);
    final t = to == null ? '…' : DateFormat('d MMM').format(to);
    return '$f–$t';
  }

  Widget _empty(ColorScheme cs) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded, size: 56, color: cs.outline),
            const SizedBox(height: 12),
            const Text('No students match these filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _studentTile(ColorScheme cs, Map<String, dynamic> s) {
    final avatar = s['avatar'] as String?;
    final url = (avatar != null && avatar.isNotEmpty)
        ? (avatar.startsWith('http') ? avatar : '$_kMediaBase$avatar')
        : null;
    final name = s['name']?.toString() ?? 'Student';
    final email = s['email']?.toString() ?? '';
    final joined = s['joinedOrgAt'];
    final joinedStr = joined is String
        ? DateFormat('d MMM yyyy').format(DateTime.parse(joined).toLocal())
        : '—';
    final programs = (s['programs'] as List?)
            ?.whereType<Map>()
            .map((e) => e['name']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentOverviewScreen(
              organizationId: widget.organizationId,
              studentId: s['userId']?.toString() ?? '',
              studentName: name,
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: cs.primary.withValues(alpha: 0.15),
          backgroundImage: url != null ? NetworkImage(url) : null,
          child: url == null
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.w700))
              : null,
        ),
        title: Text(name,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isNotEmpty)
              Text(email,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              'Joined $joinedStr  ·  ${programs.isEmpty ? 'No programs' : programs.join(', ')}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  // ── Filters bottom sheet ───────────────────────────────────────────────────
  Future<void> _openFilters() async {
    // Local copies so Cancel discards.
    String? programId = _programId;
    String? status = _status;
    DateTime? joinedFrom = _joinedFrom, joinedTo = _joinedTo;
    DateTime? enrolledFrom = _enrolledFrom, enrolledTo = _enrolledTo;
    String sortBy = _sortBy, order = _order;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> pick(bool from, bool joined) async {
              final initial = joined
                  ? (from ? joinedFrom : joinedTo)
                  : (from ? enrolledFrom : enrolledTo);
              final d = await showDatePicker(
                context: ctx,
                initialDate: initial ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d == null) return;
              setSheet(() {
                if (joined) {
                  if (from) {
                    joinedFrom = d;
                  } else {
                    joinedTo = d;
                  }
                } else {
                  if (from) {
                    enrolledFrom = d;
                  } else {
                    enrolledTo = d;
                  }
                }
              });
            }

            Widget dateRow(String label, DateTime? from, DateTime? to,
                bool joined) {
              String fmt(DateTime? d) =>
                  d == null ? 'Any' : DateFormat('d MMM yyyy').format(d);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pick(true, joined),
                          child: Text('From: ${fmt(from)}',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pick(false, joined),
                          child: Text('To: ${fmt(to)}',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filters',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    // Program
                    DropdownButtonFormField<String?>(
                      value: programId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Program',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Any program')),
                        ..._programs.map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name,
                                overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setSheet(() => programId = v),
                    ),
                    const SizedBox(height: 14),
                    // Status
                    DropdownButtonFormField<String?>(
                      value: status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Enrollment status',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Any status')),
                        ..._statusOptions.map((s) =>
                            DropdownMenuItem(value: s, child: Text(s))),
                      ],
                      onChanged: (v) => setSheet(() => status = v),
                    ),
                    const SizedBox(height: 16),
                    dateRow('Added to organization', joinedFrom, joinedTo, true),
                    const SizedBox(height: 16),
                    dateRow('Enrolled in program', enrolledFrom, enrolledTo,
                        false),
                    const SizedBox(height: 16),
                    // Sort
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: sortBy,
                            decoration: const InputDecoration(
                              labelText: 'Sort by',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'joinedAt',
                                  child: Text('Date joined')),
                              DropdownMenuItem(
                                  value: 'name', child: Text('Name')),
                            ],
                            onChanged: (v) =>
                                setSheet(() => sortBy = v ?? 'joinedAt'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          onPressed: () => setSheet(
                              () => order = order == 'asc' ? 'desc' : 'asc'),
                          icon: Icon(order == 'asc'
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded),
                          tooltip: order == 'asc' ? 'Ascending' : 'Descending',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48)),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48)),
                            child: const Text('Apply filters'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (applied == true) {
      setState(() {
        _programId = programId;
        _status = status;
        _joinedFrom = joinedFrom;
        _joinedTo = joinedTo;
        _enrolledFrom = enrolledFrom;
        _enrolledTo = enrolledTo;
        _sortBy = sortBy;
        _order = order;
      });
      _search();
    }
  }
}
