double calculateTimeProgress(DateTime? startDate, DateTime? endDate) {
  if (startDate == null || endDate == null) return 0.0;

  final now = DateTime.now();

  // Case A: Class hasn't started yet
  if (now.isBefore(startDate)) return 0.0;

  // Case B: Class has already finished
  if (now.isAfter(endDate)) return 1.0;

  final totalDuration = endDate.difference(startDate).inSeconds;
  final elapsedDuration = now.difference(startDate).inSeconds;

  if (totalDuration <= 0) return 0.0;

  // Return percentage bounded between 0.0 and 1.0
  return (elapsedDuration / totalDuration).clamp(0.0, 1.0);
}
