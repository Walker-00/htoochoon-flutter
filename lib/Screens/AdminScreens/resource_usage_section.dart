import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/subscription_provider.dart';
import 'package:htoochoon_flutter/Screens/Subsciption/subscription_screen.dart';
import 'package:htoochoon_flutter/models/api_models/subscription_model.dart';
import 'package:provider/provider.dart';

/// 📊 Plan banner + resource-usage grid. Lives in org Settings (moved out of the
/// home Overview, which now shows org-level analytics). Consumes
/// [SubscriptionProvider]; the dead "Classes" tile was removed (Class model gone).
class ResourceUsageSection extends StatefulWidget {
  final String orgId;
  const ResourceUsageSection({super.key, required this.orgId});

  @override
  State<ResourceUsageSection> createState() => _ResourceUsageSectionState();
}

class _ResourceUsageSectionState extends State<ResourceUsageSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<SubscriptionProvider>();
      if (prov.usage == null && !prov.isLoading) {
        prov.loadForOrg(widget.orgId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, prov, _) {
        final plan = prov.currentPlan;
        final usage = prov.usage;
        if (prov.isLoading && usage == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan != null) ...[
              _PlanBanner(
                plan: plan,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SubscriptionScreen()),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (usage != null)
              _UsageGrid(usage: usage)
            else
              ElevatedButton.icon(
                onPressed: () => prov.loadForOrg(widget.orgId),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Load resource usage'),
              ),
          ],
        );
      },
    );
  }
}

class _PlanBanner extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onTap;
  const _PlanBanner({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.planType.toUpperCase(),
                    style: TextStyle(
                      color: cs.onPrimary.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active Plan',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cs.onPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                plan.status.toUpperCase(),
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageGrid extends StatelessWidget {
  final DashboardUsage usage;
  const _UsageGrid({required this.usage});

  @override
  Widget build(BuildContext context) {
    final p = usage.usagePercentage;
    final items = [
      ('Students', p.students, Icons.person_rounded),
      ('Teachers', p.teachers, Icons.school_rounded),
      ('Programs', p.programs, Icons.layers_rounded),
      ('Courses', p.courses, Icons.menu_book_rounded),
      ('Storage', p.storage, Icons.storage_rounded),
    ];
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: items
          .map((i) => _UsageTile(label: i.$1, percentage: i.$2, icon: i.$3))
          .toList(),
    );
  }
}

class _UsageTile extends StatelessWidget {
  final String label;
  final int percentage;
  final IconData icon;
  const _UsageTile({required this.label, required this.percentage, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = percentage > 85
        ? Colors.red
        : percentage > 60
            ? Colors.orange
            : cs.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: color),
              Text('$percentage%',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: cs.outline.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
