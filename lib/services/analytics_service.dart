import '../models/achievement.dart';

class AnalyticsResult {
  final String bestMonth;
  final String worstMonth;

  final double averagePerMonth;
  final int activeMonths;
  final int activeDays;

  final Map<String, int> monthlyCounts;
  final Map<String, int> categoryCounts;
  final Map<String, int> weekdayCounts;
  final int longestInactivityGap;

  final double productivityChangePercentage; // vs last month

  const AnalyticsResult({
    required this.bestMonth,
    required this.worstMonth,
    required this.averagePerMonth,
    required this.activeMonths,
    required this.activeDays,
    required this.monthlyCounts,
    required this.categoryCounts,
    required this.weekdayCounts,
    required this.longestInactivityGap,
    required this.productivityChangePercentage,
  });
}

class AnalyticsService {
  AnalyticsResult analyze(List<Achievement> achievements) {
    if (achievements.isEmpty) {
      return const AnalyticsResult(
        bestMonth: "",
        worstMonth: "",
        averagePerMonth: 0,
        activeMonths: 0,
        activeDays: 0,
        monthlyCounts: {},
        categoryCounts: {},
        weekdayCounts: {},
        longestInactivityGap: 0,
        productivityChangePercentage: 0,
      );
    }

    // Sort by date
    achievements.sort((a, b) => a.date.compareTo(b.date));

    // ----------------------------------------------------
    // 1. MONTHLY COUNTS
    // ----------------------------------------------------
    final monthlyCounts = <String, int>{}; // "2024-03": 5

    for (var a in achievements) {
      final key = "${a.date.year}-${a.date.month.toString().padLeft(2, '0')}";
      monthlyCounts[key] = (monthlyCounts[key] ?? 0) + 1;
    }

    // Best month
    String bestMonth = monthlyCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    // Worst month
    String worstMonth = monthlyCounts.entries
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;

    // Average per month
    double averagePerMonth =
        achievements.length / monthlyCounts.keys.length;

    // Active months count
    int activeMonths = monthlyCounts.length;

    // ----------------------------------------------------
    // 2. CATEGORY COUNTS
    // ----------------------------------------------------
    final Map<String, int> categoryCounts = {};

    for (var a in achievements) {
      categoryCounts[a.category] = (categoryCounts[a.category] ?? 0) + 1;
    }

    // ----------------------------------------------------
    // 3. WEEKDAY ANALYTICS
    // ----------------------------------------------------
    final weekdayCounts = <String, int>{
      "Mon": 0,
      "Tue": 0,
      "Wed": 0,
      "Thu": 0,
      "Fri": 0,
      "Sat": 0,
      "Sun": 0,
    };

    for (var a in achievements) {
      final weekday = _weekdayName(a.date.weekday);
      weekdayCounts[weekday] = weekdayCounts[weekday]! + 1;
    }

    // ----------------------------------------------------
    // 4. ACTIVE DAYS COUNT
    // ----------------------------------------------------
    final activeDaySet = <String>{}; // "2024-03-18"

    for (var a in achievements) {
      final key =
          "${a.date.year}-${a.date.month}-${a.date.day}";
      activeDaySet.add(key);
    }

    final activeDays = activeDaySet.length;

    // ----------------------------------------------------
    // 5. LONGEST INACTIVITY GAP
    // ----------------------------------------------------
    int longestGap = 0;

    for (int i = 1; i < achievements.length; i++) {
      final gap = achievements[i].date
          .difference(achievements[i - 1].date)
          .inDays;

      if (gap > longestGap) longestGap = gap;
    }

    // ----------------------------------------------------
    // 6. PRODUCTIVITY CHANGE (VS LAST MONTH)
    // ----------------------------------------------------
    final sortedKeys = monthlyCounts.keys.toList()..sort();
    double productivityChange = 0;

    if (sortedKeys.length >= 2) {
      final lastMonth = monthlyCounts[sortedKeys.last]!.toDouble();
      final prevMonth =
      monthlyCounts[sortedKeys[sortedKeys.length - 2]]!.toDouble();

      if (prevMonth == 0) {
        productivityChange = lastMonth > 0 ? 100 : 0;
      } else {
        productivityChange = ((lastMonth - prevMonth) / prevMonth) * 100;
      }
    }

    return AnalyticsResult(
      bestMonth: bestMonth,
      worstMonth: worstMonth,
      averagePerMonth: averagePerMonth,
      activeMonths: activeMonths,
      activeDays: activeDays,
      monthlyCounts: monthlyCounts,
      categoryCounts: categoryCounts,
      weekdayCounts: weekdayCounts,
      longestInactivityGap: longestGap,
      productivityChangePercentage: productivityChange,
    );
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return "Mon";
      case DateTime.tuesday:
        return "Tue";
      case DateTime.wednesday:
        return "Wed";
      case DateTime.thursday:
        return "Thu";
      case DateTime.friday:
        return "Fri";
      case DateTime.saturday:
        return "Sat";
      default:
        return "Sun";
    }
  }
}
