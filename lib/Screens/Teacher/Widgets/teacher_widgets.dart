
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

// -----------------------------------------------------------------------------
// SIDEBAR ITEM
// -----------------------------------------------------------------------------
class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.primaryContainer)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? (isDark ? Colors.white : theme.colorScheme.primary)
                    : AppTheme.getTextTertiary(context),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : theme.colorScheme.primary)
                      : AppTheme.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STAT CARD (Classroom Metrics)
// -----------------------------------------------------------------------------
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool trendUp;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
        boxShadow: AppTheme.shadowSm(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (trendUp ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: trendUp ? AppTheme.success : AppTheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: trendUp ? AppTheme.success : AppTheme.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ACTION REQUIRED CARD (High Priority)
// -----------------------------------------------------------------------------
class ActionRequiredCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ActionRequiredCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusLg,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: AppTheme.borderRadiusLg,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getTextSecondary(context), // Use secondary or primary based on design
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.getTextTertiary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.getTextTertiary(context)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CLASS SCHEDULE CARD (Today's Classes)
// -----------------------------------------------------------------------------
class ClassScheduleCard extends StatelessWidget {
  final String className;
  final String time;
  final int studentCount;
  final String status; // 'Live', 'Upcoming', 'Completed'
  final VoidCallback onAction;

  const ClassScheduleCard({
    super.key,
    required this.className,
    required this.time,
    required this.studentCount,
    required this.status,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLive = status.toLowerCase() == 'live';

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(
          color: isLive ? AppTheme.error.withValues(alpha: 0.3) : AppTheme.getBorder(context),
          width: isLive ? 1.5 : 1,
        ),
        boxShadow: isLive ? [
          BoxShadow(color: AppTheme.error.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
        ] : AppTheme.shadowSm(isDark),
      ),
      child: Row(
        children: [
          // Time Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time.split(' - ')[0],
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                time.split(' - ').length > 1 ? time.split(' - ')[1] : '',
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.getTextTertiary(context)),
              ),
            ],
          ),
          const SizedBox(width: AppTheme.spaceLg),
          
          // Class Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLive)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                Text(
                  className,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 14, color: AppTheme.getTextTertiary(context)),
                    const SizedBox(width: 4),
                    Text(
                      '$studentCount Students',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.getTextTertiary(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Button
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLive ? AppTheme.error : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(isLive ? 'Join' : 'View'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LEADERBOARD ROW
// -----------------------------------------------------------------------------
class LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final String score;
  final bool trendUp;

  const LeaderboardRow({
    super.key,
    required this.rank,
    required this.name,
    required this.score,
    required this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? theme.colorScheme.primary : AppTheme.getTextTertiary(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            score,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Icon(
            trendUp ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: trendUp ? AppTheme.success : AppTheme.error,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SMART INSIGHT CARD
// -----------------------------------------------------------------------------
class SmartInsightCard extends StatelessWidget {
  final String message;
  final String trend; // e.g. "-15%"
  final bool positive;

  const SmartInsightCard({
    super.key,
    required this.message,
    required this.trend,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.getTextSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (positive ? AppTheme.success : AppTheme.error).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              trend,
              style: theme.textTheme.labelSmall?.copyWith(
                color: positive ? AppTheme.success : AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
