// lib/modules/journal/utils/weekly_summary.dart

// ⭐ Import the combined Journal module (model + helpers)
import '../models/journal_entry.dart';

// ⭐ Import proper service file
import '../services/journal_service.dart';

class WeeklySummary {
  final int entryCount;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, int> dailyActivity;

  WeeklySummary({
    required this.entryCount,
    required this.startDate,
    required this.endDate,
    required this.dailyActivity,
  });
}

class WeeklySummaryHelper {
  final JournalService _service = JournalService();

  Future<WeeklySummary> generateForLast7Days() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));

    // ⭐ Get all journal entries
    final allEntries = await _service.getAllEntries();

    // ⭐ Filter entries manually by date range
    final entries = allEntries.where((e) {
      return e.createdAt.isAfter(start) &&
          e.createdAt.isBefore(now);
    }).toList();

    // ⭐ Build daily activity map
    final Map<String, int> daily = {};

    for (var e in entries) {
      final dayKey =
          "${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}";

      daily[dayKey] = (daily[dayKey] ?? 0) + 1;
    }

    return WeeklySummary(
      entryCount: entries.length,
      startDate: start,
      endDate: now,
      dailyActivity: daily,
    );
  }
}
