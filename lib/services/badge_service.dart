import '../models/achievement.dart';
import 'streak_service.dart';

class BadgeResult {
  final List<String> badges;
  const BadgeResult(this.badges);
}

class BadgeService {
  /// MAIN FUNCTION
  BadgeResult calculateBadges(List<Achievement> achievements) {
    if (achievements.isEmpty) {
      return const BadgeResult([]);
    }

    final List<String> earned = [];

    // SORT achievements (optional)
    achievements.sort((a, b) => a.date.compareTo(b.date));

    // ------------------------------------------------------------
    // 1. FIRST ACHIEVEMENT BADGE
    // ------------------------------------------------------------
    earned.add("🎉 First Achievement");

    // ------------------------------------------------------------
    // 2. TOTAL COUNT MILESTONES
    // ------------------------------------------------------------
    final total = achievements.length;

    if (total >= 10) earned.add("🔟 10 Achievements");
    if (total >= 25) earned.add("🏅 25 Achievements");
    if (total >= 50) earned.add("🥉 50 Achievements");
    if (total >= 100) earned.add("🥈 100 Achievements");
    if (total >= 200) earned.add("🥇 200 Achievements");

    // ------------------------------------------------------------
    // 3. CATEGORY MASTERY BADGES
    // ------------------------------------------------------------
    final Map<String, int> categoryCounts = {};

    for (var a in achievements) {
      categoryCounts[a.category] = (categoryCounts[a.category] ?? 0) + 1;
    }

    categoryCounts.forEach((category, count) {
      if (count >= 5) earned.add("📌 $category Expert (5+)");
      if (count >= 10) earned.add("🏆 $category Master (10+)");
      if (count >= 20) earned.add("👑 $category Legend (20+)");
    });

    // ------------------------------------------------------------
    // 4. MONTHLY ACHIEVEMENT BADGES (consistency)
    // ------------------------------------------------------------
    final Map<String, int> monthly = {};
    for (var a in achievements) {
      final key = "${a.date.year}-${a.date.month.toString().padLeft(2, '0')}";
      monthly[key] = (monthly[key] ?? 0) + 1;
    }

    monthly.forEach((month, count) {
      if (count >= 3) earned.add("📅 $month Achiever (3+ in month)");
      if (count >= 5) earned.add("🔥 $month Power Achiever (5+ in month)");
      if (count >= 10) earned.add("⚡ $month Mega Achiever (10+ in month)");
    });

    // ------------------------------------------------------------
    // 5. STREAK BADGES (uses streak_service.dart)
    // ------------------------------------------------------------
    final streak = StreakService().calculateStreaks(achievements);

    if (streak.weeklyStreak >= 2) earned.add("🗓️ 2-Week Streak");
    if (streak.weeklyStreak >= 4) earned.add("🔥 4-Week Streak");
    if (streak.weeklyStreak >= 8) earned.add("⚡ 8-Week Streak");

    if (streak.monthlyStreak >= 2) earned.add("📆 2-Month Streak");
    if (streak.monthlyStreak >= 4) earned.add("🏅 4-Month Streak");
    if (streak.monthlyStreak >= 6) earned.add("🏆 6-Month Streak");
    if (streak.monthlyStreak >= 12) earned.add("👑 12-Month Streak");

    // ------------------------------------------------------------
    // 6. POINTS BADGES (you already have points field)
    // ------------------------------------------------------------
    int totalPoints = achievements.fold(0, (sum, a) => sum + a.points);

    if (totalPoints >= 100) earned.add("💠 100 Points");
    if (totalPoints >= 300) earned.add("💙 300 Points");
    if (totalPoints >= 500) earned.add("💜 500 Points");
    if (totalPoints >= 1000) earned.add("🧿 1000 Points Master");

    // Remove duplicates just in case
    final uniqueBadges = earned.toSet().toList();

    return BadgeResult(uniqueBadges);
  }
}
