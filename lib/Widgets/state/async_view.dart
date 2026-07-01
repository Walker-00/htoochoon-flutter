import 'package:flutter/material.dart';

import 'shimmer_skeletons.dart';
import 'empty_state.dart';
import 'error_retry.dart';

/// Which skeleton to show while loading.
enum SkeletonKind { list, grid, detail, chart, none }

/// Standardizes the loading / error / empty / loaded states for a screen so
/// every screen behaves the same (appendix §11). Drop into a body:
///
/// ```dart
/// AsyncView<List<Course>>(
///   loading: provider.isLoading,
///   error: provider.error,
///   data: provider.courses,
///   isEmpty: (c) => c.isEmpty,
///   onRetry: provider.load,
///   skeleton: SkeletonKind.list,
///   emptyTitle: 'No courses yet',
///   builder: (c) => CourseList(c),
/// )
/// ```
class AsyncView<T> extends StatelessWidget {
  final bool loading;
  final Object? error;
  final T? data;
  final bool Function(T data)? isEmpty;
  final Widget Function(T data) builder;
  final Future<void> Function()? onRetry;

  final SkeletonKind skeleton;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  const AsyncView({
    super.key,
    required this.loading,
    required this.data,
    required this.builder,
    this.error,
    this.isEmpty,
    this.onRetry,
    this.skeleton = SkeletonKind.list,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  Widget _skeleton() {
    switch (skeleton) {
      case SkeletonKind.list:
        return const ShimmerList();
      case SkeletonKind.grid:
        return const ShimmerCardGrid();
      case SkeletonKind.detail:
        return const ShimmerDetail();
      case SkeletonKind.chart:
        return const ShimmerChart();
      case SkeletonKind.none:
        return const Center(child: CircularProgressIndicator());
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    // First load (no data yet) → skeleton. Refreshing with data stays on content.
    if (loading && d == null) return _skeleton();
    if (error != null && d == null) {
      return ErrorRetry(
        message: _humanError(error),
        onRetry: onRetry,
      );
    }
    if (d == null) return _skeleton();
    if (isEmpty != null && isEmpty!(d)) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      );
    }
    return builder(d);
  }

  static String _humanError(Object? e) {
    if (e == null) return 'Something went wrong.';
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (s.contains('TimeoutException') || s.contains('timed out')) {
      return 'The request timed out. Please try again.';
    }
    if (s.contains('401') || s.contains('Unauthorized')) {
      return 'Your session expired. Please sign in again.';
    }
    return 'Couldn\'t load this right now. Please try again.';
  }
}
