import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/achievement.dart';
import '../utils/achievement_config.dart';

/// ===================================================================
/// COLOR PALETTE (PROFESSIONAL 3D THEME)
/// ===================================================================
final List<Color> kProColors = [
  Color(0xFF6C63FF),
  Color(0xFF4CC9F0),
  Color(0xFF4895EF),
  Color(0xFF4361EE),
  Color(0xFF3F37C9),
  Color(0xFF560BAD),
  Color(0xFF7209B7),
  Color(0xFFB5179E),
];

/// ===================================================================
/// RADAR DATA SERVICE (ALWAYS SHOW ALL CATEGORIES)
/// ===================================================================
class RadarCategoryData {
  final String category;
  final double value;
  RadarCategoryData(this.category, this.value);
}

class RadarDataService {
  List<RadarCategoryData> buildRadarData(List<Achievement> achievements) {
    final allCategories = AchievementCategory.values
        .map((c) => AchievementConfig.categoryToString(c))
        .toList();

    final Map<String, int> categoryCounts = {
      for (var c in allCategories) c: 0,
    };

    for (var a in achievements) {
      categoryCounts[a.category] = (categoryCounts[a.category] ?? 0) + 1;
    }

    int maxCount = categoryCounts.values.isEmpty
        ? 1
        : categoryCounts.values.reduce((a, b) => a > b ? a : b);

    return categoryCounts.entries.map((e) {
      final normalized =
      maxCount == 0 ? 0.0 : ((e.value / maxCount) * 100).toDouble();
      return RadarCategoryData(e.key, normalized);
    }).toList();
  }
}

/// ===================================================================
/// 3D RADAR CHART (Glow + Depth)
/// ===================================================================
class RadarChartWidget extends StatelessWidget {
  final List<RadarCategoryData> data;
  const RadarChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      decoration: BoxDecoration(
        color: Color(0xFFF8F8FF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade300, blurRadius: 20, offset: Offset(0, 8)),
          BoxShadow(color: Colors.white, blurRadius: 12, offset: Offset(-6, -6)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          gridBorderData: BorderSide(color: Colors.grey.shade300),
          radarBorderData: BorderSide(color: Colors.deepPurple.shade200, width: 2),
          ticksTextStyle: const TextStyle(fontSize: 11, color: Colors.grey),

          titleTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),

          getTitle: (i, angle) => RadarChartTitle(text: data[i].category),

          dataSets: [
            RadarDataSet(
              fillColor: Colors.deepPurple.withOpacity(0.25),
              borderColor: Colors.deepPurple,
              borderWidth: 2.5,
              entryRadius: 4,
              dataEntries:
              data.map((e) => RadarEntry(value: e.value)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===================================================================
/// 3D PIE CHART (Exploded + Legend)
/// ===================================================================
class CategoryPieChart extends StatelessWidget {
  final Map<String, int> categoryCounts;
  const CategoryPieChart({super.key, required this.categoryCounts});

  @override
  Widget build(BuildContext context) {
    if (categoryCounts.isEmpty) return const Text("No category data");

    final entries = categoryCounts.entries.toList();
    final total = categoryCounts.values.fold(0, (p, c) => p + c);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8F8FF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade300, blurRadius: 20, offset: Offset(0, 8)),
          BoxShadow(color: Colors.white, blurRadius: 12, offset: Offset(-6, -6)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 45,
                sections: List.generate(entries.length, (i) {
                  final item = entries[i];
                  final percentage = (item.value / total) * 100;

                  return PieChartSectionData(
                    color: kProColors[i % kProColors.length],
                    value: item.value.toDouble(),
                    radius: 65,
                    title: "${percentage.toStringAsFixed(1)}%",
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    badgeWidget: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        item.key.substring(0, 2).toUpperCase(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    badgePositionPercentageOffset: 1.2,
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // LEGEND
          Column(
            children: List.generate(entries.length, (i) {
              final item = entries[i];
              final percentage = (item.value / total) * 100;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: kProColors[i % kProColors.length],
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${item.key} • ${item.value} (${percentage.toStringAsFixed(1)}%)",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// ===================================================================
/// REAL-WORLD PROFESSIONAL 12-MONTH BAR CHART WITH YEAR HEADER
/// ===================================================================
class MonthlyBarChart extends StatelessWidget {
  final Map<String, int> monthlyCounts;
  const MonthlyBarChart({super.key, required this.monthlyCounts});

  @override
  Widget build(BuildContext context) {
    if (monthlyCounts.isEmpty) {
      return const Text("No monthly data available");
    }

    // Extract year from key like "2024-03"
    final int displayedYear =
    int.parse(monthlyCounts.keys.first.split("-")[0]);

    // Full 12 months default 0
    final Map<int, int> monthlyData = {
      for (int m = 1; m <= 12; m++) m: 0,
    };

    // Fill actual values
    monthlyCounts.forEach((key, count) {
      final month = int.parse(key.split("-")[1]);
      monthlyData[month] = count;
    });

    final monthsLabels = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8F8FF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade300, blurRadius: 20, offset: Offset(0, 8)),
          BoxShadow(color: Colors.white, blurRadius: 12, offset: Offset(-6, -6)),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ⭐ YEAR HEADER ⭐
          Text(
            displayedYear.toString(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,

                maxY: (monthlyData.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),

                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.black87,
                    tooltipPadding: const EdgeInsets.all(10),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        "${monthsLabels[group.x - 1]}\n${rod.toY.toInt()} achievements",
                        const TextStyle(color: Colors.white, fontSize: 14),
                      );
                    },
                  ),
                ),

                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        int monthIndex = value.toInt();
                        if (monthIndex < 1 || monthIndex > 12) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            monthsLabels[monthIndex - 1],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),

                barGroups: List.generate(12, (i) {
                  final month = i + 1;
                  final count = monthlyData[month]!.toDouble();
                  final baseColor = kProColors[i % kProColors.length];

                  return BarChartGroupData(
                    x: month,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        width: 18,
                        color: baseColor,
                        borderRadius: BorderRadius.circular(8),

                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            count,
                            baseColor.withOpacity(0.25),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
              swapAnimationDuration: const Duration(milliseconds: 900),
              swapAnimationCurve: Curves.easeOutBack,
            ),
          ),
        ],
      ),
    );
  }
}


