import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/classroom_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/submission_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/submission_feedback_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/take_assignment_screen.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/Screens/Discussion/discussion_list_screen.dart';
import 'package:htoochoon_flutter/Providers/assignment_provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/models/api_models/assignment_model.dart';
import 'package:htoochoon_flutter/models/api_models/submission_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────
// create_assignment_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/widgets/rich_content.dart';
import 'package:htoochoon_flutter/widgets/markdown_field.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:retrofit/retrofit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA HOLDER — used only while building a question inside the form
// ─────────────────────────────────────────────────────────────────────────────

class _OptionDraft {
  String label;
  String text;
  bool isCorrect;

  _OptionDraft({required this.label, this.text = '', this.isCorrect = false});
}

/// A question the teacher is building before submission.
/// [attachedFiles] are the actual File objects selected for THIS question.
/// [fileIndices] are filled in just before submission by counting globally.
class _QuestionDraft {
  int order;
  QuestionType type;
  final TextEditingController textCtrl;
  int points;
  bool isRequired;
  List<_OptionDraft> options;

  /// Files chosen for this specific question (in the order selected)
  List<PlatformFile> attachedFiles;

  _QuestionDraft({
    required this.order,
    this.type = QuestionType.MULTIPLE_CHOICE,
    required this.textCtrl,
    this.points = 5,
    this.isRequired = true,
    List<_OptionDraft>? options,
    List<PlatformFile>? attachedFiles,
  }) : options =
           options ?? [_OptionDraft(label: 'A'), _OptionDraft(label: 'B')],
       attachedFiles = attachedFiles ?? [];

  void dispose() => textCtrl.dispose();
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE / EDIT ASSIGNMENT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CreateAssignmentScreen extends StatefulWidget {
  final String classId;

  /// true → creates a TEST, false → ASSIGNMENT
  final bool isTest;

  final bool isTemplate;

  const CreateAssignmentScreen({
    super.key,
    required this.classId,
    this.isTest = false,
    this.isTemplate = false,
  });

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '60');

  // Optional relative deadline ("due X after publish"). Empty = no deadline.
  final _dueAmountCtrl = TextEditingController();
  String _dueUnit = 'days'; // 'hours' | 'days'
  bool _showContentPreview = true;

  // Anti-cheat safety policy chosen for this exam (see exam_safety.dart).
  String _safetyLevel = 'MID'; // NONE | MID | HIGH | EXTREME
  String _safetyScope = 'MOBILE'; // ALL | DESKTOP | MOBILE
  String _safetyMeasure = 'CAMERA'; // CAMERA | NETWORK  (HIGH only)

  int? get _dueDurationMinutes {
    final n = int.tryParse(_dueAmountCtrl.text.trim());
    if (n == null || n <= 0) return null;
    return _dueUnit == 'hours' ? n * 60 : n * 60 * 24;
  }
  bool _isSaving = false;

  final List<_QuestionDraft> _questions = [];

  Widget _buildSafetySection(BuildContext context) {
    const levels = [
      ['NONE', 'None'],
      ['MID', 'Mid'],
      ['HIGH', 'High'],
      ['EXTREME', 'Extreme'],
    ];
    const desc = {
      'NONE': 'No anti-cheat monitoring for this exam.',
      'MID': 'Flags app-switching / leaving the exam. Works on every platform.',
      'HIGH': 'App-switch detection plus ONE measure you pick below.',
      'EXTREME':
          'Everything: camera behaviour + network detection + room scan + an '
              'active network block (asks for admin/sudo on desktop, VPN on Android).',
    };
    Widget chips(List<List<String>> opts, String current, void Function(String) on) =>
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opts
              .map((o) => ChoiceChip(
                    label: Text(o[1]),
                    selected: current == o[0],
                    onSelected: (_) => on(o[0]),
                  ))
              .toList(),
        );

    return _SectionCard(
      title: 'Exam safety (anti-cheat)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chips(levels, _safetyLevel, (v) => setState(() => _safetyLevel = v)),
          const SizedBox(height: 6),
          Text(desc[_safetyLevel] ?? '', style: const TextStyle(fontSize: 12)),
          if (_safetyLevel == 'HIGH') ...[
            const SizedBox(height: 12),
            const Text('Measure',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 4),
            chips(const [
              ['CAMERA', 'Camera behaviour'],
              ['NETWORK', 'Network (proxy/VPN/IP)'],
            ], _safetyMeasure, (v) => setState(() => _safetyMeasure = v)),
          ],
          if (_safetyLevel == 'HIGH' || _safetyLevel == 'EXTREME') ...[
            const SizedBox(height: 12),
            const Text('Enforce on',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 4),
            chips(const [
              ['ALL', 'All platforms'],
              ['DESKTOP', 'Desktop only'],
              ['MOBILE', 'Mobile only'],
            ], _safetyScope, (v) => setState(() => _safetyScope = v)),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Camera proctoring is mobile-only; desktop enforces network '
                'detection (and block at Extreme).',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // EXAMS are question-based → start with one question. ASSIGNMENTS are
    // submission-based (students upload/type a response) → no questions.
    if (widget.isTest) _addQuestion();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _durationCtrl.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(
        _QuestionDraft(
          order: _questions.length + 1,
          textCtrl: TextEditingController(),
        ),
      );
    });
  }

  void _onQuestionTypeChanged(_QuestionDraft q, QuestionType newType) {
    setState(() {
      q.type = newType;

      if (newType == QuestionType.TRUE_FALSE) {
        // ✅ Removed the 'id' parameter to match your _OptionDraft constructor definition
        q.options = [
          _OptionDraft(label: 'A', text: 'True', isCorrect: false),
          _OptionDraft(label: 'B', text: 'False', isCorrect: false),
        ];
      } else if (newType == QuestionType.MULTIPLE_CHOICE) {
        q.options = [
          _OptionDraft(label: 'A', text: '', isCorrect: false),
          _OptionDraft(label: 'B', text: '', isCorrect: false),
        ];
      } else {
        q.options.clear();
      }
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
      // re-order
      for (int i = 0; i < _questions.length; i++) {
        _questions[i].order = i + 1;
      }
    });
  }

  ///JHSHJSHJDHAJSDHKJAHSDKJHKASJHNDJKMSAJH
  Future<void> _pickFiles(int questionIndex) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'pdf',
        'doc',
        'docx',
        'xlsx',
        'mp4',
        'mp3',
      ],
    );

    if (result == null) return;

    final files = result.files.map((file) {
      // Web-safe handling: use bytes instead of path
      if (file.bytes != null) {
        return file; // keep FilePicker file object for web
      }

      // Mobile/Desktop fallback (has path)
      if (file.path != null) {
        return File(file.path!);
      }

      throw Exception("Unsupported file format");
    }).toList();

    setState(() {
      _questions[questionIndex].attachedFiles.addAll(result.files);
    });
  }

  void _removeFile(int questionIndex, int fileIndex) {
    setState(() {
      _questions[questionIndex].attachedFiles.removeAt(fileIndex);
    });
  }

  /// Builds the flat attachment list AND computes per-question file indices.
  /// Builds the flat attachment list AND computes per-question file indices.
  ///
  /// Walk questions in order, accumulate files. Each question gets the
  /// global indices [startIdx .. startIdx + count - 1].
  ///
  /// Returns:
  ///   - flatFiles: all files in order for the multipart `attachments` field
  ///   - questionFileIndices: Map<questionOrder, List<int>>
  ({List<PlatformFile> flatFiles, Map<int, List<int>> questionFileIndices})
  _buildFileIndex() {
    final flatFiles = <PlatformFile>[];
    final questionFileIndices = <int, List<int>>{};

    for (final q in _questions) {
      final indices = <int>[];
      for (final f in q.attachedFiles) {
        indices.add(flatFiles.length); // current global index
        flatFiles.add(f);
      }
      questionFileIndices[q.order] = indices;
    }

    return (flatFiles: flatFiles, questionFileIndices: questionFileIndices);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Please enter a title');
      return;
    }
    // Question validation applies to EXAMS only. Submission-based ASSIGNMENTS
    // have no questions — the student submits a written response instead.
    if (widget.isTest) {
      if (_questions.isEmpty) {
        _snack('Add at least one question');
        return;
      }
      for (final q in _questions) {
        if (q.textCtrl.text.trim().isEmpty) {
          _snack('Question ${q.order} text is empty');
          return;
        }
        if (q.type == QuestionType.MULTIPLE_CHOICE ||
            q.type == QuestionType.TRUE_FALSE) {
          if (!q.options.any((o) => o.isCorrect)) {
            _snack('Question ${q.order} needs a correct answer');
            return;
          }
          for (final opt in q.options) {
            if (opt.text.trim().isEmpty) {
              _snack('Question ${q.order} has an empty option');
              return;
            }
          }
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      // 1. Build flat file list + per-question indices
      final (:flatFiles, :questionFileIndices) = _buildFileIndex();

      // Debug — verify indices before sending
      debugPrint('📁 Total flat files: ${flatFiles.length}');
      for (final q in _questions) {
        debugPrint(
          'Q${q.order} indices: ${questionFileIndices[q.order]} '
          '| files: ${q.attachedFiles.length}',
        );
      }

      // Safety check — catch bad indices before they hit the API
      for (final q in _questions) {
        final indices = questionFileIndices[q.order] ?? [];
        for (final idx in indices) {
          if (idx >= flatFiles.length) {
            _snack(
              'Internal error: file index $idx out of range for Q${q.order}',
            );
            return;
          }
        }
      }

      // 2. Build questions JSON  ← FIX: was _[questions.map] (corrupted)
      final questionsJson = _questions.map((q) {
        return QuestionRequest(
          order: q.order,
          type: q.type,
          text: q.textCtrl.text.trim(),
          points: q.points,
          isRequired: q.isRequired,
          files: questionFileIndices[q.order] ?? [],
          options: q.options
              .map(
                (o) => OptionRequest(
                  label: o.label,
                  text: o.text.trim(),
                  isCorrect: o.isCorrect ? true : null,
                ),
              )
              .toList(),
        ).toJson();
      }).toList();

      debugPrint('📋 Questions JSON: ${jsonEncode(questionsJson)}');

      // 3. Convert File list → MultipartFile  ← FIX: was [flatFiles.map] (corrupted)
      // final multipartFiles = await Future.wait(
      //   flatFiles.map(
      //     (f) => MultipartFile.fromFile(
      //       f.path.toString(),
      //       filename: (f.path?.split('/').last ?? 'untitled'),
      //     ),
      //   ),
      // );
      final multipartFiles = await Future.wait(
        flatFiles.map((f) async {
          if (f.bytes != null) {
            return MultipartFile.fromBytes(f.bytes!, filename: f.name);
          }

          if (f.path != null) {
            return MultipartFile.fromFile(f.path!, filename: f.name);
          }

          throw Exception("Unsupported file format");
        }),
      );

      // 4. Call API  ← FIX: was [context.read] (corrupted)
      final provider = context.read<AssignmentProvider>();
      final created = await provider.createAssignment(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        classId: widget.classId, // carries the courseId
        type: widget.isTest ? AssignmentType.TEST : AssignmentType.ASSIGNMENT,
        dueDurationMinutes: _dueDurationMinutes,
        duration: int.tryParse(_durationCtrl.text) ?? 60,
        showContentPreview: _showContentPreview,
        questionsJson: jsonEncode(questionsJson),
        attachments: multipartFiles.isEmpty ? null : multipartFiles,
        safetyLevel: _safetyLevel,
        safetyScope: _safetyScope,
        safetyMeasure: _safetyMeasure,
      );

      if (!mounted) return;

      // ❗ Only claim success when the server actually returned the created
      // item. Previously the toast fired unconditionally, so a failed create
      // looked successful while the exam never appeared in the list.
      if (created == null) {
        _snack('Error: ${provider.error ?? 'Failed to create'}');
        return;
      }

      // Program (non-template) courses publish on create; templates stay draft.
      if (!widget.isTemplate) {
        await provider.updateAssignment(created.id, {
          'published': true,
          if (_dueDurationMinutes != null) 'dueDurationMinutes': _dueDurationMinutes,
          'safetyLevel': _safetyLevel,
          'safetyScope': _safetyScope,
          'safetyMeasure': _safetyMeasure,
        });
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isTest ? 'Exam created!' : 'Assignment created!',
          ),
        ),
      );
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = widget.isTest ? 'Exam' : 'Assignment';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create $label',
          style: TextStyle(color: Theme.of(context).colorScheme.background),
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _submit,
                  child: Text(
                    widget.isTemplate ? 'Save' : 'Publish',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          // ── Meta section ──────────────────────────────────
          _SectionCard(
            title: 'Details',
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                MarkdownField(
                  controller: _contentCtrl,
                  label: 'Instructions',
                  hint: 'Add instructions… **bold**, *italic*, - lists',
                ),
                const SizedBox(height: 12),
                if (widget.isTest) ...[
                  TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration (min)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Optional relative deadline — due X hours/days AFTER it's
                // published. Leave the amount empty for no deadline. (Drafts
                // stay unpublished; publishing is a separate action.)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dueAmountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Due after (optional)',
                          hintText: 'e.g. 7',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _dueUnit,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Unit (after publish)',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'hours', child: Text('Hours')),
                          DropdownMenuItem(value: 'days', child: Text('Days')),
                        ],
                        onChanged: (v) => setState(() => _dueUnit = v ?? 'days'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.isTest)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Let students preview content'),
                    subtitle: Text(
                      _showContentPreview
                          ? 'Students can see the questions before starting.'
                          : 'Questions stay hidden until the student starts the exam.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: _showContentPreview,
                    onChanged: (v) => setState(() => _showContentPreview = v),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spaceLg),

          _buildSafetySection(context),

          const SizedBox(height: AppTheme.spaceLg),

          // ── Questions (EXAMS) or submission note (ASSIGNMENTS) ────────────
          if (widget.isTest) ...[
            Row(
              children: [
                Text(
                  'Questions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSm),
            ..._questions.asMap().entries.map(
              (entry) => _QuestionCard(
                index: entry.key,
                draft: entry.value,
                onRemove: () => _removeQuestion(entry.key),
                onPickFiles: () => _pickFiles(entry.key),
                onRemoveFile: (fi) => _removeFile(entry.key, fi),
                onChanged: () => setState(() {}),
              ),
            ),
          ] else
            _SectionCard(
              title: 'How students submit',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: cs.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Students complete this assignment by writing a '
                          'response. You grade it manually and leave feedback.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A rich document editor and file attachments are coming soon.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION CARD
// ─────────────────────────────────────────────────────────────────────────────

// class _QuestionCard extends StatelessWidget {
//   final int index;
//   final _QuestionDraft draft;
//   final VoidCallback onRemove;
//   final VoidCallback onPickFiles;
//   final void Function(int fileIndex) onRemoveFile;
//   final VoidCallback onChanged;
//
//   const _QuestionCard({
//     required this.index,
//     required this.draft,
//     required this.onRemove,
//     required this.onPickFiles,
//     required this.onRemoveFile,
//     required this.onChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return _SectionCard(
//       title: 'Question ${draft.order}',
//       trailing: IconButton(
//         icon: Icon(Icons.delete_outline, color: Colors.red[400]),
//         onPressed: onRemove,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ── Type selector ───────────────────────────────
//           DropdownButtonFormField<QuestionType>(
//             value: draft.type,
//             decoration: const InputDecoration(
//               labelText: 'Question Type',
//               border: OutlineInputBorder(),
//             ),
//             items: QuestionType.values
//                 .map(
//                   (t) => DropdownMenuItem(
//                     value: t,
//                     child: Text(t.name.replaceAll('_', ' ')),
//                   ),
//                 )
//                 .toList(),
//             onChanged: (v) {
//               if (v != null) {
//                 draft.type = v;
//                 onChanged();
//               }
//             },
//           ),
//
//           const SizedBox(height: 12),
//
//           // ── Question text ───────────────────────────────
//           TextField(
//             controller: draft.textCtrl,
//             maxLines: 3,
//             onChanged: (_) => onChanged(),
//             decoration: const InputDecoration(
//               labelText: 'Question Text (HTML supported)',
//               border: OutlineInputBorder(),
//               hintText: '<p>Your question here…</p>',
//             ),
//           ),
//
//           const SizedBox(height: 12),
//
//           // ── Points ──────────────────────────────────────
//           Row(
//             children: [
//               const Text('Points: '),
//               const SizedBox(width: 8),
//               SizedBox(
//                 width: 70,
//                 child: TextFormField(
//                   initialValue: draft.points.toString(),
//                   keyboardType: TextInputType.number,
//                   decoration: const InputDecoration(
//                     border: OutlineInputBorder(),
//                     contentPadding: EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 8,
//                     ),
//                   ),
//                   onChanged: (v) {
//                     draft.points = int.tryParse(v) ?? draft.points;
//                   },
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//
//           // ── isRequired toggle ────────────────────────────────
//           Row(
//             children: [
//               const Text('Required'),
//               const Spacer(),
//               Switch(
//                 value: draft.isRequired,
//                 onChanged: (v) {
//                   draft.isRequired = v;
//                   onChanged();
//                 },
//               ),
//             ],
//           ),
//           // ── Attachments ─────────────────────────────────
//           const SizedBox(height: 16),
//
//           Row(
//             children: [
//               Text(
//                 'Attachments',
//                 style: Theme.of(context).textTheme.labelLarge,
//               ),
//               const Spacer(),
//               TextButton.icon(
//                 onPressed: onPickFiles,
//                 icon: const Icon(Icons.attach_file, size: 16),
//                 label: const Text('Add Files'),
//                 style: TextButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           if (draft.attachedFiles.isNotEmpty) ...[
//             const SizedBox(height: 8),
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: draft.attachedFiles.asMap().entries.map((e) {
//                 final fi = e.key;
//                 final file = e.value;
//                 final name = (file.path?.split('/').last ?? 'untitled');
//                 final isImage =
//                     name.toLowerCase().endsWith('.png') ||
//                     name.toLowerCase().endsWith('.jpg') ||
//                     name.toLowerCase().endsWith('.jpeg') ||
//                     name.toLowerCase().endsWith('.webp') ||
//                     name.toLowerCase().endsWith('.gif');
//
//                 return Stack(
//                   clipBehavior: Clip.none,
//                   children: [
//                     Container(
//                       width: 80,
//                       height: 80,
//                       decoration: BoxDecoration(
//                         color: cs.primary.withValues(alpha: 0.07),
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
//                       ),
//                       child: isImage
//                           ? ClipRRect(
//                               borderRadius: BorderRadius.circular(7),
//
//                               child: file.bytes != null
//                                   ? Image.memory(file.bytes!, fit: BoxFit.cover)
//                                   : Image.file(
//                                       File(file.path!),
//
//                                       fit: BoxFit.cover,
//                                     ),
//                             )
//                           : Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.insert_drive_file,
//                                   color: cs.primary,
//                                   size: 28,
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 4,
//                                   ),
//                                   child: Text(
//                                     name,
//                                     maxLines: 2,
//                                     overflow: TextOverflow.ellipsis,
//                                     textAlign: TextAlign.center,
//                                     style: const TextStyle(fontSize: 9),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                     ),
//                     Positioned(
//                       top: -6,
//                       right: -6,
//                       child: GestureDetector(
//                         onTap: () => onRemoveFile(fi),
//                         child: Container(
//                           width: 20,
//                           height: 20,
//                           decoration: const BoxDecoration(
//                             color: Colors.red,
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Icon(
//                             Icons.close,
//                             color: Colors.white,
//                             size: 12,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ],
//           if (q.type == QuestionType.TRUE_FALSE) ...[
//             const SizedBox(height: AppTheme.spaceSm),
//             const Text(
//               'Select Correct Answer:',
//               style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 6),
//             Row(
//               children: q.options.map((opt) {
//                 final isThisCorrect = opt.isCorrect;
//                 return Expanded(
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 4.0),
//                     child: OutlinedButton(
//                       style: OutlinedButton.styleFrom(
//                         backgroundColor: isThisCorrect ? Colors.green.withValues(alpha: 0.12) : null,
//                         side: BorderSide(
//                           color: isThisCorrect ? Colors.green : Colors.grey.withValues(alpha: 0.4),
//                           width: isThisCorrect ? 2 : 1,
//                         ),
//                         foregroundColor: isThisCorrect ? Colors.green[700] : null,
//                       ),
//                       onPressed: () {
//                         setState(() {
//                           // Set current option to true, turn others off
//                           for (var o in q.options) {
//                             o.isCorrect = (o.id == opt.id);
//                           }
//                         });
//                       },
//                       child: Text(opt.text),
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           ]
//
//           // ── Options (MULTIPLE_CHOICE only) ───────────────
//           if (draft.type == QuestionType.MULTIPLE_CHOICE) ...[
//             const SizedBox(height: 16),
//             Text('Options', style: Theme.of(context).textTheme.labelLarge),
//             const SizedBox(height: 8),
//             ...draft.options.asMap().entries.map(
//               (e) => _OptionRow(
//                 key: ValueKey('${draft.order}_${e.key}'),
//                 index: e.key,
//                 opt: e.value,
//                 onChanged: onChanged,
//                 onRemove: draft.options.length > 2
//                     ? () {
//                         draft.options.removeAt(e.key);
//                         // re-label A B C …
//                         for (int i = 0; i < draft.options.length; i++) {
//                           draft.options[i].label = String.fromCharCode(65 + i);
//                         }
//                         onChanged();
//                       }
//                     : null,
//               ),
//             ),
//             const SizedBox(height: 8),
//             TextButton.icon(
//               onPressed: () {
//                 draft.options.add(
//                   _OptionDraft(
//                     label: String.fromCharCode(65 + draft.options.length),
//                   ),
//                 );
//                 onChanged();
//               },
//               icon: const Icon(Icons.add, size: 16),
//               label: const Text('Add Option'),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

class _QuestionCard extends StatelessWidget {
  final int index;
  final _QuestionDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onPickFiles;
  final void Function(int fileIndex) onRemoveFile;
  final VoidCallback onChanged;

  const _QuestionCard({
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onPickFiles,
    required this.onRemoveFile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _SectionCard(
      title: 'Question ${draft.order}',
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: Colors.red[400]),
        onPressed: onRemove,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Type selector ───────────────────────────────
          DropdownButtonFormField<QuestionType>(
            value: draft.type,
            decoration: const InputDecoration(
              labelText: 'Question Type',
              border: OutlineInputBorder(),
            ),
            items: QuestionType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name.replaceAll('_', ' ')),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                draft.type = v;

                // ✅ Auto-seed option values when switching to TRUE_FALSE
                if (v == QuestionType.TRUE_FALSE) {
                  draft.options = [
                    _OptionDraft(label: 'A', text: 'True', isCorrect: false),
                    _OptionDraft(label: 'B', text: 'False', isCorrect: false),
                  ];
                } else if (v == QuestionType.MULTIPLE_CHOICE) {
                  draft.options = [
                    _OptionDraft(label: 'A', text: '', isCorrect: false),
                    _OptionDraft(label: 'B', text: '', isCorrect: false),
                  ];
                } else {
                  draft.options.clear();
                }

                onChanged();
              }
            },
          ),

          const SizedBox(height: 12),

          // ── Question text (Markdown) ────────────────────
          MarkdownField(
            controller: draft.textCtrl,
            label: 'Question Text',
            hint: 'e.g. What is **2 + 2**?',
            onChanged: (_) => onChanged(),
          ),

          const SizedBox(height: 12),

          // ── Points ──────────────────────────────────────
          Row(
            children: [
              const Text('Points: '),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: draft.points.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) {
                    draft.points = int.tryParse(v) ?? draft.points;
                    onChanged(); // Notify wrapper tree of data mutation
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── isRequired toggle ────────────────────────────────
          Row(
            children: [
              const Text('Required'),
              const Spacer(),
              Switch(
                value: draft.isRequired,
                onChanged: (v) {
                  draft.isRequired = v;
                  onChanged();
                },
              ),
            ],
          ),

          // ── Attachments ─────────────────────────────────
          const SizedBox(height: 16),

          Row(
            children: [
              Text(
                'Attachments',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onPickFiles,
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Add Files'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),

          if (draft.attachedFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: draft.attachedFiles.asMap().entries.map((e) {
                final fi = e.key;
                final file = e.value;
                final name = (file.path?.split('/').last ?? 'untitled');
                final isImage =
                    name.toLowerCase().endsWith('.png') ||
                    name.toLowerCase().endsWith('.jpg') ||
                    name.toLowerCase().endsWith('.jpeg') ||
                    name.toLowerCase().endsWith('.webp') ||
                    name.toLowerCase().endsWith('.gif');

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                      ),
                      child: isImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: file.bytes != null
                                  ? Image.memory(file.bytes!, fit: BoxFit.cover)
                                  : Image.file(
                                      File(file.path!),
                                      fit: BoxFit.cover,
                                    ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.insert_drive_file,
                                  color: cs.primary,
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => onRemoveFile(fi),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],

          // ── True/False Binary Answer Grid ───────────────────────
          // ✅ Corrected variable scopes and parameter signatures
          if (draft.type == QuestionType.TRUE_FALSE) ...[
            const SizedBox(height: 12),
            const Text(
              'Select Correct Answer:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: draft.options.map((opt) {
                final isThisCorrect = opt.isCorrect;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isThisCorrect
                            ? Colors.green.withValues(alpha: 0.12)
                            : null,
                        side: BorderSide(
                          color: isThisCorrect
                              ? Colors.green
                              : Colors.grey.withValues(alpha: 0.4),
                          width: isThisCorrect ? 2 : 1,
                        ),
                        foregroundColor: isThisCorrect
                            ? Colors.green[700]
                            : null,
                      ),
                      onPressed: () {
                        // Toggle matching states, then invoke global callback pipeline
                        for (var o in draft.options) {
                          o.isCorrect = (o.text == opt.text);
                        }
                        onChanged();
                      },
                      child: Text(opt.text),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // ── Options (MULTIPLE_CHOICE only) ───────────────
          if (draft.type == QuestionType.MULTIPLE_CHOICE) ...[
            const SizedBox(height: 16),
            Text('Options', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            // Discoverability: the lettered circle is the correct-answer toggle.
            Text(
              'Tap the letter circle to mark the correct answer.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            ...draft.options.asMap().entries.map(
              (e) => _OptionRow(
                key: ValueKey('${draft.order}_${e.key}'),
                index: e.key,
                opt: e.value,
                onChanged: onChanged,
                onRemove: draft.options.length > 2
                    ? () {
                        draft.options.removeAt(e.key);
                        // re-label A B C …
                        for (int i = 0; i < draft.options.length; i++) {
                          draft.options[i].label = String.fromCharCode(65 + i);
                        }
                        onChanged();
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                draft.options.add(
                  _OptionDraft(
                    label: String.fromCharCode(65 + draft.options.length),
                  ),
                );
                onChanged();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Option'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTION ROW
// ─────────────────────────────────────────────────────────────────────────────

class _OptionRow extends StatefulWidget {
  final int index;
  final _OptionDraft opt;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _OptionRow({
    super.key,
    required this.index,
    required this.opt,
    required this.onChanged,
    this.onRemove,
  });

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.opt.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Correct indicator
          GestureDetector(
            onTap: () {
              setState(() => widget.opt.isCorrect = !widget.opt.isCorrect);
              widget.onChanged();
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.opt.isCorrect
                    ? Colors.green
                    : cs.outline.withValues(alpha: 0.2),
              ),
              child: Center(
                child: Text(
                  widget.opt.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.opt.isCorrect ? Colors.white : cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: (v) {
                widget.opt.text = v;
                widget.onChanged();
              },
              decoration: InputDecoration(
                hintText: 'Option ${widget.opt.label}',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          if (widget.onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: widget.onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ASSIGNMENT DETAIL SCREEN  (read-only, student + teacher)
// ─────────────────────────────────────────────────────────────────────────────

class AssignmentDetailScreen extends StatefulWidget {
  final Assignment assignment;
  final String classId;
  final bool isAdminOrTeacher;
  final String studentId;
  final Submission? existingSubmission;
  final bool isAssignment;

  const AssignmentDetailScreen({
    super.key,
    this.existingSubmission,
    required this.assignment,

    required this.classId,
    required this.isAdminOrTeacher,
    required this.studentId,
    required this.isAssignment,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  List<Submission> _submissions = [];
  bool _isLoading = false;
  Assignment? _detailedAssignment;
  bool _loadingDetails = true;

  Future<void> _loadDetails() async {
    try {
      final full = await context.read<AssignmentProvider>().getAssignmentById(
        widget.assignment.id,
      );

      if (!mounted) return;

      setState(() {
        _detailedAssignment = full;
        _loadingDetails = false;
      });
    } catch (e) {
      debugPrint("Failed to load assignment details: $e");
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
    if (widget.isAdminOrTeacher) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Defer to next microtask to ensure build is complete
        Future.microtask(() async {
          if (!mounted) return;
          setState(() => _isLoading = true);

          try {
            if (widget.isAssignment) {
              _submissions = await context
                  .read<AssignmentProvider>()
                  .fetchStudentSubmissions(
                    studentId: widget.studentId,
                    type: "assignment",
                    classId: widget.classId.toString(),
                    itemId: widget.assignment.id,
                  );
            } else {
              _submissions = await context
                  .read<AssignmentProvider>()
                  .fetchStudentSubmissions(
                    studentId: widget.studentId,
                    type: "test",
                    classId: widget.classId.toString(),
                    itemId: widget.assignment.id,
                  );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // logD("Assignment ${widget.assignment!.questions!.length}");
    logD(
      "Sumission ${widget.existingSubmission?.answers?.length ?? 'nullll'}",
    );
    final cs = Theme.of(context).colorScheme;
    final a = _detailedAssignment ?? widget.assignment;
    final isOverdue =
        a.dueDate != null && a.dueDate!.isBefore(DateTime.now());
    final totalPoints = a.questions.fold<int>(0, (sum, q) => sum + q.points);
    final isSubmitted = widget.existingSubmission != null;
    final isGraded = widget.existingSubmission?.status == "GRADED";
    if (_loadingDetails && _detailedAssignment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final gradedSubmission = (isGraded && widget.existingSubmission != null)
        ? widget.existingSubmission
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.title),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Q&A',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DiscussionListScreen(
                  assignmentId: a.id,
                  assignmentTitle: a.title,
                ),
              ),
            ),
          ),
          if (widget.isAdminOrTeacher)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GradeSubmissionsScreen(
                    assignment: a,
                    classId: widget.classId,
                  ),
                ),
              ),
              child: const Text(
                'Submissions',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          // ── Result revoked notice (student view) ──────────
          if (!widget.isAdminOrTeacher &&
              (widget.existingSubmission?.isRevoked ?? false)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: AppTheme.borderRadiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gpp_bad, color: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your result has been revoked',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((widget.existingSubmission?.revokedReason ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.existingSubmission!.revokedReason!,
                      style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Contact your teacher or administrator if you have questions.',
                    style: TextStyle(
                      color: cs.onErrorContainer.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],
          // ── Due date + points banner ──────────────────
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: isOverdue
                  ? Colors.red.withValues(alpha: 0.06)
                  : cs.primary.withValues(alpha: 0.06),
              borderRadius: AppTheme.borderRadiusMd,
              border: Border.all(
                color: isOverdue
                    ? Colors.red.withValues(alpha: 0.2)
                    : cs.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isOverdue ? Colors.red : cs.primary,
                ),
                const SizedBox(width: 8),
                // --- ONLY THE DATE WILL ELLIPSIS ---
                Expanded(
                  child: Text(
                    isOverdue
                        ? 'Overdue · ${_formatDate(a.dueDate)}'
                        : 'Due ${_formatDate(a.dueDate)}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isOverdue ? Colors.red : cs.primary,
                    ),
                  ),
                ),
                const Spacer(), // Pushes points to the far right
                Icon(Icons.star_outline, size: 16, color: cs.primary),
                const SizedBox(width: 4),
                // This side stays un-wrapped, so it will always display fully
                Text(
                  '$totalPoints pts · ${a.duration} min',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spaceLg),

          // ── Instructions ──────────────────────────────
          if (a.content.isNotEmpty && a.content != '<p></p>') ...[
            Text(
              'Instructions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            RichContent(a.content),
            const SizedBox(height: AppTheme.spaceLg),
          ],

          // ── ASSIGNMENT (submission-based): show the student's written
          //    response once submitted; teachers grade it from "Submissions". ──
          if (a.type == AssignmentType.ASSIGNMENT) ...[
            if (isSubmitted &&
                !widget.isAdminOrTeacher &&
                (widget.existingSubmission?.content?.trim().isNotEmpty ??
                    false)) ...[
              Text(
                'Your response',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: AppTheme.borderRadiusMd,
                  border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                ),
                child: Text(widget.existingSubmission!.content!.trim()),
              ),
            ],
          ]
          // ── EXAM questions preview ────────────────────
          // When the creator disabled content preview, a student who hasn't
          // started yet only sees a locked notice (teachers/admins always see
          // the questions, and a submitted student sees their own answers).
          else if (!widget.isAdminOrTeacher &&
              !a.showContentPreview &&
              !isSubmitted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: AppTheme.borderRadiusMd,
                border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.lock_outline, size: 36, color: cs.primary),
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(
                    'Exam content is hidden',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${a.questions.length} question(s). The questions appear only after you start the exam.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Questions (${a.questions.length})',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.spaceMd),

            ...a.questions.map((q) {
              // ✅ Find student's answer for this question (if submitted)
              final studentAnswer = isSubmitted
                  ? widget.existingSubmission?.answers?.firstWhereOrNull(
                      (ans) => ans.questionId == q.id,
                    )
                  : null;

              // ✅ Use _QuestionPreviewCard that accepts studentAnswer
              return _QuestionPreviewCard(
                isAdminOrTeacher: widget.isAdminOrTeacher,
                question: q,
                studentAnswer: studentAnswer, // ✅ Pass answer if available
                showStudentAnswer:
                    isSubmitted &&
                    !widget.isAdminOrTeacher, // ✅ Flag to show answer
              );
            }),
          ],

          const SizedBox(height: AppTheme.space2xl),
          // ── Student: Action button ────────────────────
          // ── Student: Action button ────────────────────
          const SizedBox(height: AppTheme.space2xl),
          // ── Student: Action button ────────────────────
          if (!widget.isAdminOrTeacher)
            if (!isSubmitted)
              // ✅ UNsubmitted → Show normal submit button. EXAMS open the timed,
              //    proctored question runner; ASSIGNMENTS open the written-response
              //    submission screen.
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isOverdue
                      ? null
                      : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => a.type == AssignmentType.ASSIGNMENT
                                ? SubmitAssignmentScreen(
                                    assignment: a,
                                    studentId: widget.studentId,
                                  )
                                : TakeAssignmentScreen(
                                    accessment: a,
                                    studentId: widget.studentId,
                                  ),
                          ),
                        ),
                  icon: Icon(
                    isOverdue ? Icons.lock_clock_outlined : Icons.edit_outlined,
                  ),
                  label: Text(
                    isOverdue
                        ? 'Overdue (Submission Closed)'
                        : (a.type == AssignmentType.TEST
                              ? 'Take Exam'
                              : 'Submit Assignment'),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spaceMd,
                    ),
                  ),
                ),
              )
            else if (a.type == AssignmentType.ASSIGNMENT)
              // Submission-based assignment already submitted → show grade status.
              _AssignmentSubmittedStatus(
                submission: widget.existingSubmission!,
              )
            else ...[
              // ✅ SUBMITTED CASE (Handle Autograding Check)
              (() {
                final currentSubmission = widget.existingSubmission!;

                // 1. Check if everything can be auto-evaluated
                final bool isAutoGradable = a.questions.every(
                  (q) =>
                      q.type == QuestionType.MULTIPLE_CHOICE ||
                      q.type == QuestionType.TRUE_FALSE,
                );

                Submission finalSubmission = currentSubmission;
                bool displayAsGraded = isGraded;

                if (isAutoGradable && currentSubmission.answers != null) {
                  displayAsGraded =
                      true; // Overrule display layout to graded layout

                  num computedScore = 0;
                  final List<SubmissionAnswer> processedAnswers = [];

                  for (var q in a.questions) {
                    final studentAns = (currentSubmission.answers ?? const [])
                        .firstWhereOrNull((ans) => ans.questionId == q.id);

                    if (studentAns != null) {
                      // Find target correct option config setup
                      final correctOption = q.options.firstWhereOrNull(
                        (opt) => opt.isCorrect == true,
                      );
                      final bool isCorrectMatch =
                          correctOption != null &&
                          studentAns.selectedOptionId == correctOption.id;
                      final num pointsAwarded = isCorrectMatch ? q.points : 0;

                      computedScore += pointsAwarded;

                      processedAnswers.add(
                        studentAns.copyWith(
                          isCorrect: isCorrectMatch,
                          pointsEarned: pointsAwarded,
                        ),
                      );
                    }
                  }

                  finalSubmission = currentSubmission.copyWith(
                    status: "GRADED",
                    score: computedScore,
                    answers: processedAnswers,
                  );
                }

                if (displayAsGraded) {
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final navigator = Navigator.of(
                            context,
                            rootNavigator: true,
                          );
                          final provider = context.read<AssignmentProvider>();
                          final fullAssignment = await provider
                              .fetchAssignmentDetail(a.id);

                          if (fullAssignment == null) return;

                          navigator.pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => SubmissionFeedbackScreen(
                                assignment: fullAssignment,
                                submission:
                                    finalSubmission, // Pass client-graded or back-graded object
                                classId: widget.classId,
                                studentId: widget.studentId,
                              ),
                            ),
                          );
                        } catch (e, s) {
                          debugPrint("ERROR: $e");
                          debugPrintStack(stackTrace: s);
                        }
                      },
                      icon: const Icon(Icons.feedback_outlined),
                      label: const Text('View Feedback'),
                    ),
                  );
                } else {
                  // Fallback layout block for manual grades (Short Answer / Essay)
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spaceMd,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: AppTheme.borderRadiusMd,
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.blue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Submitted · Pending Manual Grade',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }()),
            ],

          // ── Student: submit button ────────────────────
          // if (!widget.isAdminOrTeacher && !isSubmitted) ...[
          //   SizedBox(
          //     width: double.infinity,
          //     child: FilledButton.icon(
          //       onPressed: () => Navigator.pushReplacement(
          //         context,
          //         MaterialPageRoute(
          //           builder: (_) => TakeAssignmentScreen(
          //             assignment: a,
          //             studentId: widget.studentId,
          //           ),
          //         ),
          //       ),
          //       icon: const Icon(Icons.edit_outlined),
          //       label: Text(
          //         isGraded
          //             ? 'View Feedback'
          //             : isSubmitted
          //             ? 'Submitted (Pending Grade)' // ✅ Changed label
          //             : (a.type == AssignmentType.TEST
          //                   ? 'Take Exam'
          //                   : 'Submit Assignment'),
          //       ),
          //       style: FilledButton.styleFrom(
          //         padding: const EdgeInsets.symmetric(
          //           vertical: AppTheme.spaceMd,
          //         ),
          //       ),
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION PREVIEW CARD  (read-only detail view)
// ─────────────────────────────────────────────────────────────────────────────
// In _QuestionPreviewCard or a new _QuestionReviewCard:
// Pass submission.answers to the widget
// ─────────────────────────────────────────────────────────────────────────────
// QUESTION FEEDBACK CARD  (for SubmissionFeedbackScreen - read-only review)
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionPreviewCard extends StatelessWidget {
  final Question question;
  final SubmissionAnswer? studentAnswer;
  final bool showStudentAnswer;
  final bool isAdminOrTeacher;
  const _QuestionPreviewCard({
    required this.isAdminOrTeacher,
    required this.question,
    this.studentAnswer,
    this.showStudentAnswer = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseUrl = 'https://backend.htoochoon.com';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMd,
              AppTheme.spaceMd,
              AppTheme.spaceMd,
              0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q${question.order}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurfaceVariant(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    question.type.name.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const Spacer(),
                Text(
                  '${question.points} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Question text (HTML)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs),
            child: RichContent(question.text),
          ),

          // Attachments
          if ((question.attachments?.isNotEmpty ?? false)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                0,
                AppTheme.spaceMd,
                AppTheme.spaceSm,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (question.attachments ?? []).map((att) {
                  final isImage = att.fileType.startsWith('image/');
                  final url = '$baseUrl${att.fileUrl}';
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                    ),
                    child: isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: cs.primary.withValues(alpha: 0.05),
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: cs.primary,
                                    size: 24,
                                  ),
                                );
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                color: cs.primary,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  att.fileName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                            ],
                          ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Options
          if (question.options.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                children: question.options.map((opt) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: (opt.isCorrect && isAdminOrTeacher)
                          ? Colors.green.withValues(alpha: 0.08)
                          : AppTheme.getSurfaceVariant(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (opt.isCorrect && isAdminOrTeacher)
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (opt.isCorrect && isAdminOrTeacher)
                                ? Colors.green
                                : cs.outline.withValues(alpha: 0.2),
                          ),
                          child: Center(
                            child: Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: (opt.isCorrect && isAdminOrTeacher)
                                    ? Colors.white
                                    : cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(opt.text)),
                        if (opt.isCorrect && isAdminOrTeacher)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (showStudentAnswer && studentAnswer != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Answer:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  // For MULTIPLE_CHOICE: show selected option text
                  if (question.type == QuestionType.MULTIPLE_CHOICE)
                    Text(
                      question.options
                              .firstWhereOrNull(
                                (o) => o.id == studentAnswer!.selectedOptionId,
                              )
                              ?.text ??
                          'No answer selected',
                    )
                  // For SHORT_ANSWER/ESSAY: show text answer
                  else if (studentAnswer!.textAnswer != null)
                    SmartAnswerText(
                      raw: studentAnswer!.textAnswer!,
                      context: context,
                    )
                  else
                    Text(
                      'No answer',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  // else
                  //   Text(studentAnswer!.textAnswer ?? 'No answer'),

                  // ✅ Optional: show correctness indicator if graded
                  if (studentAnswer?.isCorrect != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            studentAnswer!.isCorrect!
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: studentAnswer!.isCorrect!
                                ? Colors.green
                                : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            studentAnswer!.isCorrect! ? 'Correct' : 'Incorrect',
                            style: TextStyle(
                              color: studentAnswer!.isCorrect!
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAKE ASSIGNMENT SCREEN  (student answers questions)
// ─────────────────────────────────────────────────────────────────────────────

class _AnswerCard extends StatelessWidget {
  final Question question;
  final String? selectedOptionId;
  final void Function(String optionId) onOptionSelected;
  final void Function(String text) onTextChanged;

  const _AnswerCard({
    required this.question,
    this.selectedOptionId,
    required this.onOptionSelected,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseUrl = 'https://backend.htoochoon.com';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMd,
              AppTheme.spaceMd,
              AppTheme.spaceMd,
              0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q${question.order}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (question.isRequired) ...[
                  const SizedBox(width: 6),
                  const Text(
                    '* Required',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${question.points} pts',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Question HTML
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs),
            child: RichContent(question.text),
          ),

          // Attachments
          (question.attachments.isNotEmpty)
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMd,
                    0,
                    AppTheme.spaceMd,
                    AppTheme.spaceSm,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: question.attachments.map((att) {
                      final isImage = att.fileType.startsWith('image/');
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.getBorder(context),
                          ),
                        ),
                        child: isImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.network(
                                  '$baseUrl${att.fileUrl}',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.insert_drive_file, size: 32),
                                  const SizedBox(height: 4),
                                  Text(
                                    att.fileName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                      );
                    }).toList(),
                  ),
                )
              : SizedBox(),

          const Divider(height: 1),

          // Answer area
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: question.type == QuestionType.MULTIPLE_CHOICE
                ? Column(
                    children: question.options.map((opt) {
                      final selected = selectedOptionId == opt.id;
                      return GestureDetector(
                        onTap: () => onOptionSelected(opt.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? cs.primary.withValues(alpha: 0.1)
                                : AppTheme.getSurfaceVariant(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? cs.primary : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? cs.primary
                                      : cs.outline.withValues(alpha: 0.2),
                                ),
                                child: Center(
                                  child: Text(
                                    opt.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? Colors.white
                                          : cs.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(opt.text)),
                              if (selected)
                                Icon(
                                  Icons.check_circle,
                                  color: cs.primary,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : TextField(
                    maxLines: 5,
                    onChanged: onTextChanged,
                    decoration: const InputDecoration(
                      hintText: 'Write your answer here…',
                      border: OutlineInputBorder(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-grade helpers (shared by the teacher submissions list + tile)
// ─────────────────────────────────────────────────────────────────────────────

/// True when every question is objective (no ESSAY / SHORT_ANSWER), so the exam
/// can be graded entirely by the system.
bool _isAutoGradable(List<Question> qs) =>
    qs.isNotEmpty &&
    qs.every((q) =>
        q.type == QuestionType.MULTIPLE_CHOICE ||
        q.type == QuestionType.TRUE_FALSE);

/// Effective (display) grade for a submission. If the backend already marked it
/// GRADED we trust that; otherwise — for fully auto-gradable exams — we recompute
/// the objective score client-side so the teacher list never shows an
/// auto-graded exam as "Pending". Mirrors the student feedback view.
({bool graded, num score}) _effectiveGrade(Submission s, List<Question> qs) {
  if (s.status.toUpperCase() == 'GRADED') {
    return (graded: true, score: s.score ?? 0);
  }
  if (_isAutoGradable(qs) && s.answers != null) {
    num computed = 0;
    for (final q in qs) {
      final ans =
          (s.answers ?? const []).firstWhereOrNull((a) => a.questionId == q.id);
      if (ans == null) continue;
      final correct = q.options.firstWhereOrNull((o) => o.isCorrect == true);
      final isMatch = correct != null && ans.selectedOptionId == correct.id;
      if (isMatch) computed += q.points;
    }
    return (graded: true, score: computed);
  }
  return (graded: false, score: s.score ?? 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADE SUBMISSIONS SCREEN  (teacher view)
// ─────────────────────────────────────────────────────────────────────────────

class GradeSubmissionsScreen extends StatefulWidget {
  final Assignment assignment;
  final String classId;

  const GradeSubmissionsScreen({
    super.key,
    required this.assignment,
    required this.classId,
  });

  @override
  State<GradeSubmissionsScreen> createState() => _GradeSubmissionsScreenState();
}

class _GradeSubmissionsScreenState extends State<GradeSubmissionsScreen> {
  bool _isLoading = true;
  List<Submission> _submissions = [];
  int _totalPoints = 0;
  Assignment? _detail;

  List<Question> get _questions => _detail?.questions ?? const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prov = context.read<AssignmentProvider>();

    await prov.fetchAssignmentDetail(widget.assignment.id);

    final detailedAssignment = prov.assignmentDetails;
    _detail = detailedAssignment;

    _totalPoints =
        detailedAssignment?.questions.fold<int>(
          0,
          (sum, q) => sum + q.points,
        ) ??
        0;

    await prov.fetchSubmissions(
      classId: widget.classId,
      type: widget.assignment.type == AssignmentType.TEST
          ? 'test'
          : 'assignment',
      itemId: widget.assignment.id,
    );

    if (!mounted) return;

    setState(() {
      // ── DEDUPLICATE HERE ─────────────────────────────────────────────────
      // Using a Map literal filters out duplicate keys (submission.id)
      final uniqueMap = {for (var s in prov.submissions) s.id: s};

      _submissions = uniqueMap.values.toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = widget.assignment;
    final totalPoints = _totalPoints;

    final graded = _submissions
        .where((s) => _effectiveGrade(s, _questions).graded)
        .length;
    // In build():

    // final totalPoints =
    //     fullAssignment?.questions.fold<int>(0, (s, q) => s + q.points) ?? 0;
    // final graded = _submissions
    //     .where((s) => s.status == SubmissionStatus.GRADED.toString())
    //     .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.title),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Stats banner ──────────────────────────
                Container(
                  color: cs.primary.withValues(alpha: 0.05),
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatChip(
                        label: 'Submissions',
                        value: '${_submissions.length}',
                        icon: Icons.assignment_turned_in_outlined,
                      ),
                      _StatChip(
                        label: 'Graded',
                        value: '$graded',
                        icon: Icons.grading,
                      ),
                      _StatChip(
                        label: 'Pending',
                        value: '${_submissions.length - graded}',
                        icon: Icons.pending_outlined,
                      ),
                      _StatChip(
                        label: 'Total pts',
                        value: '$totalPoints',
                        icon: Icons.star_outline,
                      ),
                    ],
                  ),
                ),

                // ── Submission list ───────────────────────
                if (_submissions.isEmpty)
                  const Expanded(
                    child: Center(child: Text('No submissions yet')),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      itemCount: _submissions.length,
                      itemBuilder: (context, i) {
                        logD("SUBMISSION LENGTH = ${_submissions.length}");
                        return _GradeSubmissionTile(
                          submission: _submissions[i],
                          assignment: a,
                          questions: _questions,
                          totalPoints: totalPoints,
                          onGraded: (updated) {
                            setState(() => _submissions[i] = updated);
                          },
                          onRefresh: () {
                            final typeParam =
                                widget.assignment.type == AssignmentType.TEST
                                ? 'test'
                                : 'assignment';
                            context.read<AssignmentProvider>().fetchSubmissions(
                              classId: widget.classId,
                              type: typeParam,
                              itemId: widget.assignment.id,
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADE SUBMISSION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _GradeSubmissionTile extends StatelessWidget {
  final Submission submission;
  final Assignment assignment;
  final List<Question> questions;
  final int totalPoints;
  final void Function(Submission updated) onGraded;
  final VoidCallback? onRefresh;
  const _GradeSubmissionTile({
    required this.submission,
    required this.assignment,
    this.questions = const [],
    required this.totalPoints,
    required this.onGraded,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final eff = _effectiveGrade(submission, questions);
    final isGraded = eff.graded;
    final displayScore = eff.score;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(
          color: isGraded
              ? Colors.green.withValues(alpha: 0.3)
              : AppTheme.getBorder(context),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: 4,
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Text(
                  (submission.student?.name ?? '').isNotEmpty
                      ? submission.student!.name![0]
                            .toUpperCase() // ✅ Safe: ?? '' ensures non-null
                      : '?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.student?.name ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (submission.student?.email != null)
                      Text(
                        submission.student?.email ?? 'No email',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    if (_hasIntegritySignal) ...[
                      const SizedBox(height: 4),
                      _integrityChip(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
          trailing: isGraded
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: submission.isRevoked
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: (submission.isRevoked
                                    ? Colors.red
                                    : Colors.green)
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        submission.isRevoked
                            ? 'Revoked'
                            : '${displayScore.toStringAsFixed(0)} / $totalPoints',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color:
                              submission.isRevoked ? Colors.red : Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Result actions',
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (v) {
                        if (v == 'open') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentSubmissionDetailScreen(
                                submission: submission,
                                assignment: assignment,
                                isEditMode: true,
                                onGradeComplete: () => onRefresh?.call(),
                              ),
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'open',
                          child: ListTile(
                            leading: Icon(submission.isRevoked
                                ? Icons.restore
                                : Icons.block),
                            title: Text(submission.isRevoked
                                ? 'Review / restore result'
                                : 'Review / revoke result'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentSubmissionDetailScreen(
                          submission: submission,
                          assignment: assignment,

                          // total: totalPoints,
                          onGradeComplete: () {
                            onRefresh?.call();
                          },
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Grade'),
                ),
          children: [
            // ── Exam integrity (anti-cheat) summary ───────
            if (_hasIntegritySignal)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  0,
                  AppTheme.spaceMd,
                  AppTheme.spaceMd,
                ),
                child: _buildProctorSummary(context),
              ),
            // ── Per-question answers ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                0,
                AppTheme.spaceMd,
                AppTheme.spaceMd,
              ),
              child: _buildAnswerReview(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Anti-cheat helpers ──────────────────────────────────────────────────
  bool get _hasIntegritySignal =>
      (submission.cheatScore ?? 0) > 0 ||
      (submission.flagged ?? false) ||
      (submission.forcedExit ?? false) ||
      (submission.violationCount ?? 0) > 0 ||
      // Show the panel for any proctored attempt so teachers see the network +
      // room-scan status (e.g. "protected" / "clear") even on a clean exam.
      ((submission.proctorReport?['network'] is Map) ||
          ((submission.proctorReport?['camera'] is Map) &&
              (submission.proctorReport!['camera'] as Map)['roomScan'] is Map));

  Color _integrityColor(int score) {
    if (score >= 70) return Colors.red;
    if (score >= 30) return Colors.orange;
    return Colors.green;
  }

  Widget _integrityChip(BuildContext context) {
    final score = submission.cheatScore ?? 0;
    final forced = submission.forcedExit ?? false;
    final color = forced ? Colors.red : _integrityColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(forced ? Icons.gpp_bad_outlined : Icons.shield_outlined,
              size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            forced ? 'Exam ended · integrity $score/100' : 'Integrity $score/100',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProctorSummary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = submission.cheatScore ?? 0;
    final color = _integrityColor(score);
    final report = submission.proctorReport;
    final violations =
        (report?['violations'] as List?)?.cast<dynamic>() ?? const [];

    String fmtTs(dynamic ts) {
      final d = DateTime.tryParse('${ts ?? ''}')?.toLocal();
      if (d == null) return '';
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                'Exam integrity',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              const Spacer(),
              Text(
                '$score / 100',
                style: TextStyle(fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (submission.forcedExit ?? false)
                _tag(context, 'Forced exit', Colors.red),
              if (submission.flagged ?? false)
                _tag(context, 'Flagged', Colors.orange),
              _tag(
                context,
                '${submission.violationCount ?? violations.length} event(s)',
                cs.primary,
              ),
              ..._networkTags(context, report),
              ..._roomScanTags(context, report),
            ],
          ),
          _networkDetail(context, report),
          Text(
            'Higher score = more likely cheating. Advisory only — it does not change the grade.',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (violations.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Timeline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 4),
            ...violations.map((v) {
              final m = (v as Map).cast<String, dynamic>();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${fmtTs(m['timestamp'])} · ${m['description'] ?? 'Left the app'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (submission.forcedExit == true) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _approveRetake(context),
                icon: const Icon(Icons.lock_open, size: 16),
                label: const Text('Approve retake (unlock for student)'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Teacher/admin action: clear the exam lock so the student can retake.
  Future<void> _approveRetake(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final provider = context.read<AssignmentProvider>();
    final courseId = assignment.classId; // normalized to courseId post-refactor
    final assessmentId = submission.effectiveAssessmentId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve retake?'),
        content: Text(
          'This unlocks "${assignment.title}" for ${submission.student?.name ?? 'this student'} '
          'and removes their flagged attempt so they can take it again.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (confirm != true) return;

    // Find this student's lock for this exam, then approve it by id.
    final locks = await provider.listExamLocks(courseId, status: 'ALL');
    final match = locks.cast<dynamic>().firstWhere(
      (l) =>
          l is Map &&
          l['studentId'] == submission.studentId &&
          l['assessmentId'] == assessmentId &&
          l['status'] == 'LOCKED',
      orElse: () => null,
    );
    if (match == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('No active lock found (already unlocked).')),
      );
      return;
    }
    final ok = await provider.approveExamRetake('${(match as Map)['id']}');
    messenger?.showSnackBar(SnackBar(
      content: Text(ok
          ? '✅ Retake approved — the student can take the exam again.'
          : '❌ Could not approve. Try again.'),
    ));
  }

  Widget _tag(BuildContext context, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );

  /// Detail rows under the network chips: exactly which sites were blocked +
  /// the block window, and when a proxy/VPN was first seen. (We can't show which
  /// sites the student tried to reach — that needs packet capture — only what
  /// was blocked and when, plus detection timestamps.)
  Widget _networkDetail(BuildContext context, Map? report) {
    String hm(dynamic iso) {
      final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
      if (d == null) return '—';
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
    }

    final rows = <Widget>[];

    // ── REAL attempted-host log (Android VPN packet inspection) ──────────────
    // These are domains the device actually tried to reach during the exam,
    // recovered from DNS/TLS-SNI — and blocked by the guard. Not a static list.
    final net = report?['network'];
    if (net is Map) {
      final attempts =
          (net['attemptedDomains'] as List?)?.cast<dynamic>() ?? const [];
      if (attempts.isNotEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sites the device tried to reach (blocked):',
                  style:
                      const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...attempts.take(40).map((a) {
                final m = (a as Map).cast<String, dynamic>();
                final sus = m['suspicious'] == true;
                final cnt = (m['count'] as num?)?.toInt() ?? 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(sus ? Icons.gpp_bad : Icons.public,
                          size: 12,
                          color: sus ? Colors.red : Colors.blueGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${hm(m['first'])} · ${m['domain']}'
                          '${cnt > 1 ? ' ×$cnt' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                sus ? FontWeight.w700 : FontWeight.w400,
                            color: sus ? Colors.red : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ));
      }
    }

    // ── Desktop hosts-file block (EXTREME) ───────────────────────────────────
    // Desktop can't see what the student tried (no packet capture without root);
    // these domains were null-routed PREVENTIVELY for the window. Label it
    // honestly so nobody reads it as "the student visited these".
    final lock = report?['networkLockdown'];
    if (lock is Map && lock['blocked'] == true) {
      final count = (lock['blockedHostCount'] as num?)?.toInt() ?? 0;
      final window = '${hm(lock['appliedAt'])} → ${hm(lock['restoredAt'])}';
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Preventive block (desktop): $count answer/AI/chat domains '
          'null-routed for $window. This is the protection that was applied — '
          'not a record of sites the student opened.',
          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
        ),
      ));
    }

    final ni = report?['networkIntegrity'];
    if (ni is Map) {
      final lines = <String>[];
      if (ni['proxyDetected'] == true) {
        lines.add('Proxy first seen ${hm(ni['proxyFirstSeen'])}'
            '${ni['proxyValue'] != null ? ' (${ni['proxyValue']})' : ''}');
      }
      if (ni['vpnDetected'] == true) {
        final ifaces = (ni['vpnInterfaces'] as List?)?.join(', ') ?? '';
        lines.add('VPN first seen ${hm(ni['vpnFirstSeen'])}'
            '${ifaces.isNotEmpty ? ' ($ifaces)' : ''}');
      }
      if (lines.isNotEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines
                .map((l) => Text('• $l', style: const TextStyle(fontSize: 11.5)))
                .toList(),
          ),
        ));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  /// Network status chip(s): the active Android VpnService guard (where
  /// supported) PLUS the cross-platform passive proxy/VPN detection so the
  /// teacher sees something meaningful on desktop/iOS instead of "guard: off".
  List<Widget> _networkTags(BuildContext context, Map? report) {
    final tags = <Widget>[];

    // Active guard (Android VpnService) — only meaningful where it ran.
    final net = report?['network'];
    if (net is Map && net['supported'] == true && net['started'] == true) {
      final disconnects = (net['disconnectCount'] as num?)?.toInt() ?? 0;
      final downSecs = (net['totalDownSeconds'] as num?)?.toInt() ?? 0;
      tags.add(disconnects > 0
          ? _tag(context, 'Network off ${disconnects}x · ${downSecs}s', Colors.red)
          : _tag(context, 'Network: protected', Colors.green));

      // REAL attempted-host counts from packet inspection.
      final attempted = (net['attemptedCount'] as num?)?.toInt() ?? 0;
      final suspicious = (net['suspiciousCount'] as num?)?.toInt() ?? 0;
      if (suspicious > 0) {
        tags.add(_tag(context, '$suspicious answer-site attempt(s)', Colors.red));
      } else if (attempted > 0) {
        tags.add(_tag(context, '$attempted host(s) attempted', Colors.orange));
      }
    }

    // Passive proxy/VPN detection (every native platform).
    final ni = report?['networkIntegrity'];
    if (ni is Map) {
      final proxy = ni['proxyDetected'] == true;
      final vpn = ni['vpnDetected'] == true;
      if (proxy) {
        tags.add(_tag(context, 'Proxy detected', Colors.red));
      }
      if (vpn) {
        final ifaces =
            (ni['vpnInterfaces'] as List?)?.cast<dynamic>() ?? const [];
        tags.add(_tag(
            context,
            ifaces.isEmpty ? 'VPN detected' : 'VPN: ${ifaces.first}',
            Colors.red));
      }
      // Network fingerprint — which network the exam was taken on, and whether
      // it changed mid-exam (VPN toggled / switched networks).
      final ip = ni['publicIp'];
      if (ip is String && ip.isNotEmpty) {
        tags.add(_tag(context, 'IP $ip', Colors.blueGrey));
      }
      if (ni['ipChanged'] == true) {
        tags.add(_tag(context, 'IP changed mid-exam', Colors.red));
      }
      if (!proxy && !vpn && tags.isEmpty) {
        tags.add(_tag(context, 'Network: clean', Colors.green));
      }
    }

    // Active desktop block (EXTREME hosts-file lockdown) result. Honest wording:
    // it's a preventive null-route, not a record of what the student opened.
    final lock = report?['networkLockdown'];
    if (lock is Map && lock['attempted'] == true) {
      tags.add(lock['blocked'] == true
          ? _tag(context, 'Preventive block on', Colors.green)
          : _tag(context, 'Net block declined', Colors.orange));
    }
    // Safety level the exam was taken under.
    final safety = report?['safety'];
    if (safety is Map && safety['level'] is String) {
      tags.add(_tag(context, 'Safety: ${safety['level']}', Colors.blueGrey));
    }

    if (tags.isEmpty) {
      tags.add(_tag(context, 'Network: not monitored', Colors.grey));
    }
    return tags;
  }

  /// Pre-exam room-scan chip(s).
  List<Widget> _roomScanTags(BuildContext context, Map? report) {
    final scan = (report?['camera'] is Map)
        ? (report!['camera'] as Map)['roomScan']
        : null;
    if (scan is! Map) return const [];
    final people = (scan['peopleSeen'] as num?)?.toInt() ?? 0;
    final objects = (scan['objectLabels'] as List?)?.length ?? 0;
    if (people == 0 && objects == 0) {
      return [_tag(context, 'Room scan: clear', Colors.green)];
    }
    return [
      _tag(context, 'Room scan: $people person(s), $objects object(s)',
          Colors.orange),
    ];
  }

  Widget _buildAnswerReview(BuildContext context) {
    // Submission-based ASSIGNMENT: no questions — show the written response.
    if (assignment.questions.isEmpty) {
      final text = submission.content?.trim() ?? '';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceVariant(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text.isEmpty ? 'No written response.' : text,
        ),
      );
    }
    // ✅ Use submission.answers (List<SubmissionAnswer>) instead of parsing content
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: assignment.questions.map((q) {
        // Find the student's answer for this question

        final studentAnswer = submission.answers?.firstWhereOrNull(
          (a) => a.questionId == q.id,
        );
        // Pre-build answer widget
        final answerWidget = _buildAnswerWidget(q, studentAnswer, context);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceVariant(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichContent(q.text), // Question text
              const SizedBox(height: 6),
              answerWidget,
            ],
          ),
        );
      }).toList(),
    );
  }

  // ✅ Helper: Build answer display based on question type
  // Widget _buildAnswerWidget(
  //   Question q,
  //   SubmissionAnswer? answer,
  //   BuildContext context,
  // ) {
  //   // Not answered
  //   if (answer == null) {
  //     return Text(
  //       'Not answered',
  //       style: TextStyle(
  //         color: Colors.red.withValues(alpha: 0.7),
  //         fontStyle: FontStyle.italic,
  //       ),
  //     );
  //   }
  //
  //   // MULTIPLE_CHOICE
  //   if (q.type == QuestionType.MULTIPLE_CHOICE) {
  //     final pickedOption = q.options
  //         .where((o) => o.id == answer.selectedOptionId)
  //         .firstOrNull;
  //
  //     final correctOption = q.options
  //         .where((o) => o.isCorrect == true)
  //         .firstOrNull;
  //
  //     final isCorrect = answer.isCorrect ?? false;
  //
  //     return Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Icon(
  //               isCorrect ? Icons.check_circle : Icons.cancel,
  //               color: isCorrect ? Colors.green : Colors.red,
  //               size: 16,
  //             ),
  //             const SizedBox(width: 6),
  //             Expanded(
  //               child: Text(
  //                 'Answered: ${pickedOption?.text ?? 'No answer'}',
  //                 style: TextStyle(
  //                   color: isCorrect ? Colors.green : Colors.red,
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         if (!isCorrect && correctOption != null)
  //           Padding(
  //             padding: const EdgeInsets.only(top: 4, left: 22),
  //             child: Text(
  //               'Correct: ${correctOption.text}',
  //               style: const TextStyle(color: Colors.green, fontSize: 12),
  //             ),
  //           ),
  //       ],
  //     );
  //   }
  //
  //   // SHORT_ANSWER or ESSAY
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Your answer:',
  //         style: TextStyle(
  //           fontWeight: FontWeight.w600,
  //           color: AppTheme.getTextPrimary(context),
  //         ),
  //       ),
  //       const SizedBox(height: 4),
  //       Text(
  //         answer.textAnswer ?? 'No text answer',
  //         style: TextStyle(color: AppTheme.getTextPrimary(context)),
  //       ),
  //       // Show grading feedback if available
  //       if (answer.isCorrect != null) ...[
  //         const SizedBox(height: 8),
  //         Row(
  //           children: [
  //             Icon(
  //               answer.isCorrect! ? Icons.check_circle : Icons.cancel,
  //               color: answer.isCorrect! ? Colors.green : Colors.red,
  //               size: 16,
  //             ),
  //             const SizedBox(width: 4),
  //             Text(
  //               answer.isCorrect! ? 'Correct' : 'Incorrect',
  //               style: TextStyle(
  //                 color: answer.isCorrect! ? Colors.green : Colors.red,
  //                 fontWeight: FontWeight.w500,
  //               ),
  //             ),
  //             if (answer.pointsEarned != null)
  //               Padding(
  //                 padding: const EdgeInsets.only(left: 8),
  //                 child: Text(
  //                   '(${answer.pointsEarned}/${answer.question?.points})',
  //                   style: TextStyle(
  //                     color: AppTheme.getTextSecondary(context),
  //                     fontSize: 12,
  //                   ),
  //                 ),
  //               ),
  //           ],
  //         ),
  //       ],
  //     ],
  //   );
  // }
  Widget _buildAnswerWidget(
    Question q,
    SubmissionAnswer? answer,
    BuildContext context,
  ) {
    // ── Not answered check ─────────────────────────────────────────────────
    // An answer exists if EITHER selectedOptionId OR textAnswer is present.
    // Don't treat a missing textAnswer as "not answered" for MC questions,
    // and don't treat a missing selectedOptionId as "not answered" for text types.
    final bool hasAnswer =
        answer != null &&
        (answer.selectedOptionId != null ||
            (answer.textAnswer != null &&
                answer.textAnswer!.trim().isNotEmpty));

    if (!hasAnswer) {
      return Row(
        children: [
          Icon(
            Icons.remove_circle_outline,
            color: Colors.orange[400],
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'Not answered',
            style: TextStyle(
              color: Colors.orange[700],
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    // ── MULTIPLE_CHOICE / TRUE_FALSE ───────────────────────────────────────
    if (q.type == QuestionType.MULTIPLE_CHOICE ||
        q.type == QuestionType.TRUE_FALSE) {
      final pickedOption = q.options.firstWhereOrNull(
        (o) => o.id == answer!.selectedOptionId,
      );
      final correctOption = q.options.firstWhereOrNull(
        (o) => o.isCorrect == true,
      );
      final isCorrect = answer!.isCorrect ?? false;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Answered: ${pickedOption?.text ?? answer.selectedOptionId ?? '—'}',
                  style: TextStyle(
                    color: isCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!isCorrect && correctOption != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 22),
              child: Text(
                'Correct: ${correctOption.text}',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ),
        ],
      );
    }

    // ── SHORT_ANSWER ───────────────────────────────────────────────────────
    if (q.type == QuestionType.SHORT_ANSWER) {
      return _TextAnswerBlock(
        answer: answer!,
        useHtml: false, // plain text, no Quill involved
      );
    }

    // ── ESSAY (may contain HTML from flutter_quill) ────────────────────────
    return SmartAnswerText(raw: answer.textAnswer!, context: context);
  }

  void _showGradeDialog(BuildContext context) {
    // ✅ Ensure totalPoints is valid
    final maxScore = (totalPoints ?? 0).toDouble();
    double score = maxScore;

    // ✅ Calculate safe divisions for Slider
    final int? safeDivisions = maxScore > 0
        ? maxScore.toInt().clamp(1, 100)
        : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setInner) => AlertDialog(
          title: Text('Grade — ${submission.student?.name ?? '67'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.toStringAsFixed(0)} / ${maxScore.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Slider(
                value: score.clamp(0.0, maxScore),
                min: 0,
                max: maxScore,
                divisions: safeDivisions,
                label: score.round().toString(),
                onChanged: (v) => setInner(() => score = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx); // Close dialog first

                final finalScore = score.clamp(0.0, maxScore);

                // ✅ Build QuestionGrades list from submission answers
                final questionGrades =
                    submission.answers?.map((answer) {
                      return QuestionGrades(
                        questionId: answer.questionId,
                        pointEarned: answer.pointsEarned?.toInt() ?? 0,
                        feedback: "null",
                      );
                    }).toList() ??
                    [];

                // ✅ Build GradeRequest with ALL required fields
                final request = GradeRequest(
                  score: finalScore,
                  questionGrades: questionGrades, // ✅ Required!
                  status: SubmissionStatus.GRADED,
                );

                try {
                  final updated = await context
                      .read<AssignmentProvider>()
                      .gradeSubmission(
                        submissionId: submission.id,
                        request: request, // ✅ Pass the built request
                      );

                  // Callback after dialog closes
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (updated != null) {
                      onGraded?.call(updated);
                    }
                  });
                } catch (e) {
                  debugPrint('Grading failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save grade: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Grade'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          child,
        ],
      ),
    );
  }
}

String _formatDate(DateTime? dt) {
  if (dt == null) return 'No due date';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _TextAnswerBlock extends StatelessWidget {
  final SubmissionAnswer answer;

  /// true  → render with flutter_html (essay / rich text)
  /// false → render as plain Text (short answer)
  final bool useHtml;

  const _TextAnswerBlock({required this.answer, required this.useHtml});

  // Detect whether the stored string actually contains HTML tags.
  // Students who answered before the Quill editor was added may have
  // plain-text answers stored, so we render them as plain text even
  // when useHtml is true, to avoid showing an empty Html widget.
  static bool _looksLikeHtml(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return text.trimLeft().startsWith('<');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final raw = answer.textAnswer;
    final isEmpty = raw == null || raw.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──────────────────────────────────────────────────
        Text(
          'Student answer:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 4),

        // ── Answer content ─────────────────────────────────────────
        // ── Answer content ─────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceVariant(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: isEmpty
              ? Text(
                  '(empty)',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.getTextSecondary(context),
                  ),
                )
              : SmartAnswerText(raw: raw!, context: context),
        ),

        // ── Grading feedback ───────────────────────────────────────
        if (answer.isCorrect != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                answer.isCorrect! ? Icons.check_circle : Icons.cancel,
                color: answer.isCorrect! ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                answer.isCorrect! ? 'Correct' : 'Incorrect',
                style: TextStyle(
                  color: answer.isCorrect! ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (answer.pointsEarned != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${answer.pointsEarned} / ${answer.question?.points ?? '?'} pts',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class SmartAnswerText extends StatelessWidget {
  final String raw;

  const SmartAnswerText({required this.raw, required BuildContext context})
    : _ctx = context;

  final BuildContext _ctx;

  @override
  Widget build(BuildContext context) {
    // Hybrid render (Markdown for new content, HTML for legacy) — the same
    // shared renderer used for question text.
    return RichContent(raw);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBMIT ASSIGNMENT SCREEN  (student, submission-based)
// ─────────────────────────────────────────────────────────────────────────────
//
// Submission-based assignments (vs question-based exams) are completed by typing
// a written response. The instructor grades it by hand. This is the simple first
// version — a rich Google-Docs-style document editor + file attachments are
// planned as a later (premium) upgrade.
class SubmitAssignmentScreen extends StatefulWidget {
  final Assignment assignment;
  final String studentId;

  const SubmitAssignmentScreen({
    super.key,
    required this.assignment,
    required this.studentId,
  });

  @override
  State<SubmitAssignmentScreen> createState() => _SubmitAssignmentScreenState();
}

class _SubmitAssignmentScreenState extends State<SubmitAssignmentScreen> {
  final _responseCtrl = TextEditingController();
  late final DateTime _startedAt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _responseCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your response first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'studentId': widget.studentId,
        'assessmentId': widget.assignment.id,
        'startedAt': _startedAt.toUtc().toIso8601String(),
        'answers': <dynamic>[],
        'content': text,
      };
      final result =
          await context.read<AssignmentProvider>().submitAssignmentRaw(payload);
      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Assignment submitted!')),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = widget.assignment;
    return Scaffold(
      appBar: AppBar(
        title: Text(a.title),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          if (a.content.isNotEmpty && a.content != '<p></p>') ...[
            Text(
              'Instructions',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            RichContent(a.content),
            const SizedBox(height: AppTheme.spaceLg),
          ],
          Text(
            'Your response',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          TextField(
            controller: _responseCtrl,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Type your answer, report, or essay here…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_submitting ? 'Submitting…' : 'Submit assignment'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can submit once. Your teacher will review and grade it.',
            style:
                TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }
}

// Status card shown on the detail screen after a student submits a submission-
// based assignment: "pending review" until the instructor grades it, then the
// awarded score.
class _AssignmentSubmittedStatus extends StatelessWidget {
  final Submission submission;
  const _AssignmentSubmittedStatus({required this.submission});

  @override
  Widget build(BuildContext context) {
    final graded = submission.status.toUpperCase() == 'GRADED';
    final color = graded ? Colors.green : Colors.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            graded ? Icons.grading : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              graded
                  ? 'Graded · ${submission.score?.toStringAsFixed(0) ?? '—'} pts'
                  : 'Submitted · pending review',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: graded ? Colors.green[800] : Colors.blue[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
