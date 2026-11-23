import 'package:flutter/material.dart';
import '../models/achievement.dart';

/// ===============================================================
/// TIMELINE DATA MODELS
/// ===============================================================

class TimelineMonth {
  final String month; // "2024-03"
  final List<Achievement> achievements;

  TimelineMonth(this.month, this.achievements);
}

class TimelineYear {
  final int year;
  final List<TimelineMonth> months;

  TimelineYear(this.year, this.months);
}

/// ===============================================================
/// TIMELINE DATA SERVICE (builds Year → Month → Achievements)
/// ===============================================================

class TimelineService {
  List<TimelineYear> buildTimeline(List<Achievement> achievements) {
    if (achievements.isEmpty) return [];

    // NEWEST FIRST
    achievements.sort((a, b) => b.date.compareTo(a.date));

    final Map<int, Map<String, List<Achievement>>> structure = {};

    for (var a in achievements) {
      final year = a.date.year;
      final month =
          "${a.date.year}-${a.date.month.toString().padLeft(2, '0')}";

      structure.putIfAbsent(year, () => {});
      structure[year]!.putIfAbsent(month, () => []);
      structure[year]![month]!.add(a);
    }

    final List<TimelineYear> output = [];

    structure.forEach((year, monthMap) {
      final months = monthMap.entries.map((e) {
        return TimelineMonth(e.key, e.value);
      }).toList()
        ..sort((a, b) => b.month.compareTo(a.month));

      output.add(TimelineYear(year, months));
    });

    output.sort((a, b) => b.year.compareTo(a.year));

    return output;
  }
}

/// ===============================================================
/// TIMELINE WIDGET (UI for Year → Month → Achievements)
/// ===============================================================

class AchievementTimeline extends StatelessWidget {
  final List<TimelineYear> data;

  const AchievementTimeline({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("No achievements yet"));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: data.map((year) {
        return _buildYearTile(year);
      }).toList(),
    );
  }

  /// ---------------- YEAR TILE ----------------
  Widget _buildYearTile(TimelineYear year) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(
        year.year.toString(),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      children: year.months.map((month) => _buildMonthTile(month)).toList(),
    );
  }

  /// ---------------- MONTH TILE ----------------
  Widget _buildMonthTile(TimelineMonth month) {
    return ExpansionTile(
      initiallyExpanded: false,
      title: Text(
        _formatMonth(month.month),
        style: const TextStyle(fontSize: 16),
      ),
      children: month.achievements
          .map((a) => _buildAchievementTile(a))
          .toList(),
    );
  }

  /// ---------------- ACHIEVEMENT TILE ----------------
  Widget _buildAchievementTile(Achievement a) {
    return ListTile(
      title: Text(a.title),
      subtitle: Text(a.description),
      trailing: Text(
        "${a.date.day}/${a.date.month}",
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  /// ---------------- Month name helper ----------------
  String _formatMonth(String key) {
    final parts = key.split("-");
    final monthNum = int.parse(parts[1]);

    const monthNames = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];

    return "${monthNames[monthNum - 1]} ${parts[0]}";
  }
}
