import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';

import '../services/streak_service.dart';
import '../services/badge_service.dart';
import '../services/analytics_service.dart';

import '../services/analytics_charts.dart';     // Radar Chart
import '../services/timeline_combined.dart';        // Timeline

class AchievementAnalyticsScreen extends StatefulWidget {
  const AchievementAnalyticsScreen({super.key});

  @override
  State<AchievementAnalyticsScreen> createState() =>
      _AchievementAnalyticsScreenState();
}

class _AchievementAnalyticsScreenState
    extends State<AchievementAnalyticsScreen> {
  final AchievementService _service = AchievementService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Achievement Analytics"),
      ),

      body: StreamBuilder<List<Achievement>>(
        stream: _service.getAchievements(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final achievements = snap.data!;
          if (achievements.isEmpty) {
            return const Center(child: Text("No achievements available."));
          }

          // COMPUTE ANALYTICS
          final streak = StreakService().calculateStreaks(achievements);
          final badges = BadgeService().calculateBadges(achievements);
          final analytics = AnalyticsService().analyze(achievements);
          final radarData = RadarDataService().buildRadarData(achievements);
          final timeline = TimelineService().buildTimeline(achievements);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ---------------------------------------------------------
                // STREAK SUMMARY
                // ---------------------------------------------------------
                const Text(
                  "Streak Overview",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                _statCard("Weekly Streak", streak.weeklyStreak.toString(),
                    Icons.calendar_view_week),
                _statCard("Monthly Streak", streak.monthlyStreak.toString(),
                    Icons.calendar_month),
                _statCard("Longest Weekly Streak",
                    streak.longestWeeklyStreak.toString(), Icons.trending_up),
                _statCard("Longest Monthly Streak",
                    streak.longestMonthlyStreak.toString(), Icons.timeline),

                const SizedBox(height: 25),

                // ---------------------------------------------------------
                // BADGES
                // ---------------------------------------------------------
                const Text(
                  "Badges Earned",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  children: badges.badges
                      .map((b) => Chip(label: Text(b)))
                      .toList(),
                ),

                const SizedBox(height: 25),

                // ---------------------------------------------------------
                // RADAR CHART
                // ---------------------------------------------------------
                const Text(
                  "Category Strength Radar",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                RadarChartWidget(data: radarData),

                const SizedBox(height: 25),

                // ---------------------------------------------------------
                // PIE CHART (NEW)
                // ---------------------------------------------------------
                const Text(
                  "Category Distribution",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                CategoryPieChart(categoryCounts: analytics.categoryCounts),

                const SizedBox(height: 25),

                // ---------------------------------------------------------
                // BAR CHART (NEW)
                // ---------------------------------------------------------
                const Text(
                  "Monthly Activity",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                MonthlyBarChart(monthlyCounts: analytics.monthlyCounts),

                const SizedBox(height: 25),

                // ---------------------------------------------------------
                // BASIC STATISTICS
                // ---------------------------------------------------------
                const Text(
                  "General Statistics",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                _statCard("Best Month", analytics.bestMonth, Icons.leaderboard),
                _statCard("Worst Month", analytics.worstMonth, Icons.downhill_skiing),
                _statCard(
                    "Avg per Month",
                    analytics.averagePerMonth.toStringAsFixed(1),
                    Icons.calculate),
                _statCard(
                    "Active Months",
                    analytics.activeMonths.toString(),
                    Icons.track_changes),
                _statCard(
                    "Active Days",
                    analytics.activeDays.toString(),
                    Icons.calendar_today),
                _statCard(
                    "Productivity Change",
                    "${analytics.productivityChangePercentage.toStringAsFixed(1)}%",
                    Icons.show_chart),

                const SizedBox(height: 25),

                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.timeline),
                    label: const Text("View Full Timeline"),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.9,
                          child: AchievementTimeline(data: timeline),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          )
        ],
      ),
    );
  }
}
