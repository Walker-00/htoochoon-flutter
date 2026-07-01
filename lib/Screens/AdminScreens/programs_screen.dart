import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/programs_provider.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/widgets/program_progress_bar.dart';
import 'package:provider/provider.dart';

class ProgramsScreen extends StatefulWidget {
  final String organisationId;
  const ProgramsScreen({super.key, required this.organisationId});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgramsProvider>().fetchProgramsInOrgId(
        widget.organisationId,
      );
    });
  }

  // We need orgId for creating programs — pass via provider or constructor.
  // For this screen we read it from a stored value or prompt user.
  // String get _orgId => ''; // Replace with real orgId from context/provider.

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Consumer<ProgramsProvider>(
        builder: (_, prov, __) => CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              pinned: true,
              title: Text(
                'Programs',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.add_rounded, color: cs.onPrimary),
                  onPressed: () => _showCreateDialog(context, prov),
                ),
              ],
            ),
            if (prov.isLoading || prov.programs == null)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            if (prov.programs.isEmpty && !prov.isLoading)
              const SliverFillRemaining(child: _EmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ProgramTile(
                      program: prov.programs[i],
                      onDelete: () => prov.deleteProgram(prov.programs[i].id),
                    ),
                    childCount: prov.programs.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    ProgramsProvider prov,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    ProgramType selectedType = ProgramType.BOOTCAMP;
    DateTime? startDate;
    DateTime? endDate;

    String label(DateTime? d) => d == null
        ? 'Pick date'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pick(bool isStart) async {
            final base = isStart
                ? (startDate ?? DateTime.now())
                : (endDate ??
                    (startDate ?? DateTime.now()).add(const Duration(days: 30)));
            final d = await showDatePicker(
              context: ctx,
              initialDate: base,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              setS(() => isStart ? startDate = d : endDate = d);
            }
          }

          return AlertDialog(
            title: const Text('New Program'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProgramType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ProgramType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => selectedType = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: Text('Start: ${label(startDate)}',
                              overflow: TextOverflow.ellipsis),
                          onPressed: () => pick(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: Text('End: ${label(endDate)}',
                              overflow: TextOverflow.ellipsis),
                          onPressed: () => pick(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Start & end dates are REQUIRED — block submission otherwise.
                  if (nameCtrl.text.trim().isEmpty ||
                      startDate == null ||
                      endDate == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content:
                          Text('Name, start date and end date are required.'),
                    ));
                    return;
                  }
                  if (!endDate!.isAfter(startDate!)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('End date must be after start date.'),
                    ));
                    return;
                  }
                  Navigator.pop(ctx);
                  await prov.createProgram(
                    ProgramRequest(
                      name: nameCtrl.text.trim(),
                      description:
                          descCtrl.text.isNotEmpty ? descCtrl.text : null,
                      organizationId: widget.organisationId,
                      type: selectedType,
                      startDate: startDate!,
                      endDate: endDate!,
                    ),
                  );
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  final ProgramResponse program;
  final VoidCallback onDelete;

  const _ProgramTile({required this.program, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeColor = _color(program.type, cs);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.layers_rounded, color: typeColor),
        ),
        title: Text(
          program.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: program.description != null
            ? Text(
                program.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                program.type.name.toUpperCase(),
                style: TextStyle(
                  color: typeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onSelected: (v) {
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ProgramProgressBar(
              start: program.startDate,
              end: program.endDate,
            ),
          ),
        ],
      ),
    );
  }

  Color _color(ProgramType t, ColorScheme cs) {
    switch (t) {
      case ProgramType.DEGREE:
        return cs.primary;
      case ProgramType.CERTIFICATION:
        return cs.tertiary;
      case ProgramType.BOOTCAMP:
        return Colors.orange;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: 56, color: cs.outline),
          const SizedBox(height: 12),
          const Text(
            'No programs yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
