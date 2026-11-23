import '../models/achievement.dart';

class StreakResult {
  final int weeklyStreak;
  final int longestWeeklyStreak;

  final int monthlyStreak;
  final int longestMonthlyStreak;

  const StreakResult({
    required this.weeklyStreak,
    required this.longestWeeklyStreak,
    required this.monthlyStreak,
    required this.longestMonthlyStreak,
  });
}

class StreakService {
  /// Calculate weekly + monthly streaks based on achievement dates
  StreakResult calculateStreaks(List<Achievement> achievements) {
    if (achievements.isEmpty) {
      return const StreakResult(
        weeklyStreak: 0,
        longestWeeklyStreak: 0,
        monthlyStreak: 0,
        longestMonthlyStreak: 0,
      );
    }

    achievements.sort((a, b) => a.date.compareTo(b.date));

    // WEEKLY STREAK MAP
    final weeklyMap = <String, int>{};
    for (var a in achievements) {
      final weekKey = _makeWeekKey(a.date);
      weeklyMap[weekKey] = (weeklyMap[weekKey] ?? 0) + 1;
    }

    final weeklyStreak = _currentWeeklyStreak(weeklyMap);
    final longestWeekly = _longestWeeklyStreak(weeklyMap);

    // MONTHLY STREAK MAP
    final monthlyMap = <String, int>{};
    for (var a in achievements) {
      final monthKey = _makeMonthKey(a.date);
      monthlyMap[monthKey] = (monthlyMap[monthKey] ?? 0) + 1;
    }

    final monthlyStreak = _currentMonthlyStreak(monthlyMap);
    final longestMonthly = _longestMonthlyStreak(monthlyMap);

    return StreakResult(
      weeklyStreak: weeklyStreak,
      longestWeeklyStreak: longestWeekly,
      monthlyStreak: monthlyStreak,
      longestMonthlyStreak: longestMonthly,
    );
  }

  // ===========================================================
  // WEEKLY HELPERS
  // ===========================================================

  String _makeWeekKey(DateTime d) {
    final week = _weekNumber(d);
    return "${d.year}-W${week.toString().padLeft(2, '0')}";
  }

  int _weekNumber(DateTime date) {
    // ISO 8601 week number (Mon–Sun)
    final thursday = date.add(Duration(days: (4 - date.weekday)));
    final firstThursday = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(firstThursday).inDays) / 7).floor() + 1;
  }

  bool _isConsecutiveWeek(String prev, String next) {
    final p = prev.split("-W");
    final n = next.split("-W");

    final py = int.parse(p[0]);
    final ny = int.parse(n[0]);

    final pw = int.parse(p[1]);
    final nw = int.parse(n[1]);

    if (py == ny && nw == pw + 1) return true;
    if (ny == py + 1 && pw >= 52 && nw == 1) return true;

    return false;
  }

  int _currentWeeklyStreak(Map<String, int> weeklyMap) {
    final keys = weeklyMap.keys.toList()..sort();
    if (keys.isEmpty) return 0;

    int streak = 1;
    for (int i = keys.length - 1; i > 0; i--) {
      if (_isConsecutiveWeek(keys[i - 1], keys[i])) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _longestWeeklyStreak(Map<String, int> weeklyMap) {
    final keys = weeklyMap.keys.toList()..sort();
    if (keys.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < keys.length; i++) {
      if (_isConsecutiveWeek(keys[i - 1], keys[i])) {
        current++;
      } else {
        longest = current > longest ? current : longest;
        current = 1;
      }
    }

    return current > longest ? current : longest;
  }

  // ===========================================================
  // MONTHLY HELPERS
  // ===========================================================

  String _makeMonthKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}";
  }

  bool _isConsecutiveMonth(String prev, String next) {
    final p = prev.split("-");
    final n = next.split("-");

    final py = int.parse(p[0]);
    final ny = int.parse(n[0]);

    final pm = int.parse(p[1]);
    final nm = int.parse(n[1]);

    if (py == ny && nm == pm + 1) return true;
    if (ny == py + 1 && pm == 12 && nm == 1) return true;

    return false;
  }

  int _currentMonthlyStreak(Map<String, int> monthlyMap) {
    final keys = monthlyMap.keys.toList()..sort();
    if (keys.isEmpty) return 0;

    int streak = 1;
    for (int i = keys.length - 1; i > 0; i--) {
      if (_isConsecutiveMonth(keys[i - 1], keys[i])) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _longestMonthlyStreak(Map<String, int> monthlyMap) {
    final keys = monthlyMap.keys.toList()..sort();
    if (keys.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < keys.length; i++) {
      if (_isConsecutiveMonth(keys[i - 1], keys[i])) {
        current++;
      } else {
        longest = current > longest ? current : longest;
        current = 1;
      }
    }

    return current > longest ? current : longest;
  }
}
