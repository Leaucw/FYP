import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// Keep your existing model/service imports here
import '../models/goal.dart';
import '../models/achievement.dart';
import '../services/goal_service.dart';
import '../services/achievement_service.dart';
import 'ai_recommendation_screen.dart';
import 'mbti_analytics_screen.dart';
import 'side_navigation_drawer.dart';

/// ---------------------------------------------------------------------------
///  CONSTANTS & THEME STYLES
/// ---------------------------------------------------------------------------
const _goalCategories = [
	'Health & Wellness',
	'Career & Finance',
	'Education & Learning',
	'Relationships & Community',
	'Personal Growth',
];

class DashboardTheme {
	static const Color background = Color(0xFFF8F9FC);
	static const Color surface = Colors.white;
	static const Color primaryDeep = Color(0xFF2A2D3E);
	static const Color accentPurple = Color(0xFF6C63FF);
	static const Color accentBlue = Color(0xFF4CAF50);
	static const Color accentOrange = Color(0xFFFF6B6B);

	static BoxDecoration cardDecoration = BoxDecoration(
		color: surface,
		borderRadius: BorderRadius.circular(24),
		boxShadow: [
			BoxShadow(
				color: const Color(0xFF2A2D3E).withOpacity(0.05),
				offset: const Offset(0, 8),
				blurRadius: 24,
			),
		],
	);
}

/// ---------------------------------------------------------------------------
///  MODERN ANALYTICS DASHBOARD
/// ---------------------------------------------------------------------------
class AnalyticsDashboardScreen extends StatefulWidget {
	const AnalyticsDashboardScreen({super.key});

	@override
	State<AnalyticsDashboardScreen> createState() =>
			_AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
	final _auth = FirebaseAuth.instance;
	final _goals = GoalService(db: FirebaseFirestore.instance);
	final _achievements = AchievementService(db: FirebaseFirestore.instance);

	// Logic Variables
	String _mode = "All Time";
	int? _selectedYear;
	int? _selectedQuarterYear;
	String _selectedQuarter = "Q1";
	int? _selectedMonthYear;
	int _selectedMonth = DateTime.now().month;
	DateTimeRange? _customRange;

	@override
	Widget build(BuildContext context) {
		final user = _auth.currentUser;
		if (user == null) return const Scaffold(body: Center(child: Text("Login Required")));

		return Scaffold(
			backgroundColor: DashboardTheme.background,

			// --- DRAWER ---
			drawer: const SideNavigationDrawer(currentScreen: 'dashboard'),

			// --- BODY ---
			body: StreamBuilder<List<Goal>>(
				stream: _goals.streamGoals(user.uid),
				builder: (context, goalSnap) {
					if (!goalSnap.hasData) return const Center(child: CircularProgressIndicator());

					return StreamBuilder<List<Achievement>>(
						stream: _achievements.stream(user.uid),
						builder: (context, achSnap) {
							if (!achSnap.hasData) return const Center(child: CircularProgressIndicator());

							final goals = goalSnap.data!;
							final achs = achSnap.data!;

							// --- DATA PREP LOGIC ---
							final years = <int>{
								...goals.map((g) => g.createdAt.year),
								...goals.where((g) => g.completedAt != null).map((g) => g.completedAt!.year),
								...achs.map((a) => a.date.year),
							}.toList()..sort((a, b) => b.compareTo(a));

							_initializeDefaults(years);
							final dateRange = _calculateDateRange(years);

							final filteredGoals = goals.where((g) => _inRange(g.createdAt, dateRange)).toList();
							final filteredComplete = goals.where((g) => g.completedAt != null && _inRange(g.completedAt!, dateRange)).toList();
							final filteredAchs = achs.where((a) => _inRange(a.date, dateRange)).toList();

							final completionRate = filteredGoals.isEmpty ? 0.0 : filteredComplete.length / filteredGoals.length;

							// --- UI RENDERING ---
							return CustomScrollView(
								slivers: [

									// 1. EXPANDABLE APP BAR
									SliverAppBar(
										expandedHeight: 100.0,
										pinned: true,
										floating: false,
										backgroundColor: DashboardTheme.primaryDeep,
										foregroundColor: Colors.white,

										// Double Leading Buttons
										leadingWidth: 96,
										leading: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												IconButton(
													icon: const Icon(Icons.arrow_back),
													onPressed: () {
														if (Navigator.canPop(context)) Navigator.pop(context);
													},
												),
												Builder(
													builder: (context) => IconButton(
														icon: const Icon(Icons.menu),
														onPressed: () => Scaffold.of(context).openDrawer(),
													),
												),
											],
										),

										// Flexible Area
										flexibleSpace: FlexibleSpaceBar(
											centerTitle: true,
											// This keeps the font size constant (prevents growing/shrinking)
											expandedTitleScale: 1.0,
											titlePadding: const EdgeInsets.only(bottom: 16),
											title: Row(
												mainAxisSize: MainAxisSize.min,
												crossAxisAlignment: CrossAxisAlignment.center,
												children: [
													// The Colored Icon on the left
													Container(
														padding: const EdgeInsets.all(4),
														decoration: BoxDecoration(
															// Changed to primaryDeep to match AppBar background
															color: DashboardTheme.primaryDeep,
															borderRadius: BorderRadius.circular(6),
														),
														child: const Icon(
																Icons.insights,
																size: 18,
																color: Colors.amberAccent
														),
													),
													const SizedBox(width: 8),
													const Text(
														"Dashboard",
														style: TextStyle(
																fontSize: 20, // Fixed size
																fontWeight: FontWeight.w600,
																color: Colors.white,
														),
													),

												],
											),
											background: Stack(
												fit: StackFit.expand,
												children: [
													Container(color: DashboardTheme.primaryDeep),
													Positioned(
														right: -20,
														top: -10,
														child: Icon(
															Icons.analytics,
															size: 150,
															color: Colors.white.withOpacity(0.05),
														),
													),
												],
											),
										),
									),

									// 2. Filter Section
									SliverToBoxAdapter(
										child: Padding(
											padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
											child: _ModernFilterBar(
												mode: _mode,
												years: years,
												selectedYear: _selectedYear,
												selectedQuarterYear: _selectedQuarterYear,
												selectedQuarter: _selectedQuarter,
												selectedMonthYear: _selectedMonthYear,
												selectedMonth: _selectedMonth,
												customRange: _customRange,
												onModeChanged: (v) => setState(() => _mode = v),
												onYearChanged: (v) => setState(() => _selectedYear = v),
												onQYearChanged: (v) => setState(() => _selectedQuarterYear = v),
												onQuarterChanged: (v) => setState(() => _selectedQuarter = v),
												onMYearChanged: (v) => setState(() => _selectedMonthYear = v),
												onMonthChanged: (v) => setState(() => _selectedMonth = v!),
												onDateRangeTap: () async {
													final picked = await showDateRangePicker(
															context: context,
															firstDate: DateTime(2000),
															lastDate: DateTime(2100),
															builder: (context, child) {
																return Theme(
																	data: ThemeData.light().copyWith(
																		colorScheme: const ColorScheme.light(primary: DashboardTheme.primaryDeep),
																	),
																	child: child!,
																);
															}
													);
													if (picked != null) setState(() => _customRange = picked);
												},
											),
										),
									),

									// 3. Hero Stats Grid
									SliverPadding(
										padding: const EdgeInsets.all(20),
										sliver: SliverGrid.count(
											crossAxisCount: 2,
											crossAxisSpacing: 16,
											mainAxisSpacing: 16,
											childAspectRatio: 1.5,
											children: [
												_HeroStatCard(
													title: "Goals Created",
													value: "${filteredGoals.length}",
													icon: Icons.flag_rounded,
													color: Colors.blueAccent,
													delay: 0,
												),
												_HeroStatCard(
													title: "Achievements",
													value: "${filteredAchs.length}",
													icon: Icons.emoji_events_rounded,
													color: Colors.orangeAccent,
													delay: 100,
												),
												_HeroStatCard(
													title: "Completion",
													value: "${(completionRate * 100).toStringAsFixed(0)}%",
													subtitle: "Success Rate",
													icon: Icons.pie_chart_rounded,
													color: Colors.green,
													delay: 200,
												),
												_HeroStatCard(
													title: "Completed",
													value: "${filteredComplete.length}",
													icon: Icons.check_circle_outline_rounded,
													color: Colors.purpleAccent,
													delay: 300,
												),
											],
										),
									),

									// 4. Charts Section
									SliverToBoxAdapter(
										child: Padding(
											padding: const EdgeInsets.symmetric(horizontal: 20),
											child: Column(
												children: [
													_SectionHeader(title: "Monthly Trends (Goals)", icon: Icons.bar_chart),
													const SizedBox(height: 12),
													_ChartContainer(
														child: _buildMonthlyBarChart(filteredGoals, filteredComplete),
													),

													const SizedBox(height: 32),
													_SectionHeader(title: "Category Distribution (Goals)", icon: Icons.donut_large),
													const SizedBox(height: 12),
													_ChartContainer(
														child: _buildModernPieChart(filteredGoals),
													),

													const SizedBox(height: 32),
													_SectionHeader(title: "Performance Radar (Goals)", icon: Icons.radar),
													const SizedBox(height: 12),
													_ChartContainer(
														height: 350,
														child: _buildRadarChart(filteredGoals, filteredComplete),
													),
													const SizedBox(height: 50),
												],
											),
										),
									),
								],
							);
						},
					);
				},
			),
		);
	}

	// --- LOGIC HELPERS ---
	void _initializeDefaults(List<int> years) {
		if (_mode == "Year" && _selectedYear == null && years.isNotEmpty) _selectedYear = years.first;
		if (_mode == "Quarter" && _selectedQuarterYear == null && years.isNotEmpty) _selectedQuarterYear = years.first;
		if (_mode == "Month" && _selectedMonthYear == null && years.isNotEmpty) _selectedMonthYear = years.first;
	}

	({DateTime? start, DateTime? end}) _calculateDateRange(List<int> years) {
		DateTime? start, end;
		const quarterMap = {'Q1': [1, 3], 'Q2': [4, 6], 'Q3': [7, 9], 'Q4': [10, 12]};

		if (_mode == 'Year' && _selectedYear != null) {
			start = DateTime(_selectedYear!, 1, 1);
			end = DateTime(_selectedYear!, 12, 31, 23, 59, 59);
		} else if (_mode == 'Quarter' && _selectedQuarterYear != null) {
			final q = quarterMap[_selectedQuarter]!;
			start = DateTime(_selectedQuarterYear!, q[0], 1);
			end = DateTime(_selectedQuarterYear!, q[1], DateTime(_selectedQuarterYear!, q[1] + 1, 0).day, 23, 59, 59);
		} else if (_mode == 'Month' && _selectedMonthYear != null) {
			start = DateTime(_selectedMonthYear!, _selectedMonth, 1);
			end = DateTime(_selectedMonthYear!, _selectedMonth, DateTime(_selectedMonthYear!, _selectedMonth + 1, 0).day, 23, 59, 59);
		} else if (_mode == 'Custom' && _customRange != null) {
			start = _customRange!.start;
			end = _customRange!.end;
		}
		return (start: start, end: end);
	}

	bool _inRange(DateTime d, ({DateTime? start, DateTime? end}) range) {
		if (range.start != null && d.isBefore(range.start!)) return false;
		if (range.end != null && d.isAfter(range.end!)) return false;
		return true;
	}

	// --- WIDGET BUILDERS ---



	Widget _buildMonthlyBarChart(List<Goal> started, List<Goal> completed) {
		final sData = List.filled(12, 0);
		final cData = List.filled(12, 0);
		for (var g in started) sData[g.createdAt.month - 1]++;
		for (var g in completed) cData[g.completedAt!.month - 1]++;

		// Find max value to add top padding so labels don't get cut off
		int maxY = 0;
		for (int i = 0; i < 12; i++) {
			if (sData[i] > maxY) maxY = sData[i];
			if (cData[i] > maxY) maxY = cData[i];
		}

		return BarChart(
			BarChartData(
				maxY: maxY + 1.5, // Add buffer space for the text labels
				barTouchData: BarTouchData(
					enabled: false, // Disable user interaction (static labels)
					touchTooltipData: BarTouchTooltipData(
						// Make background transparent so it looks like a text label
						getTooltipColor: (_) => Colors.transparent,
						tooltipPadding: EdgeInsets.zero,
						tooltipMargin: 4, // Distance from top of bar
						getTooltipItem: (group, groupIndex, rod, rodIndex) {
							// Only show if value > 0 to keep it clean
							if (rod.toY == 0) return null;
							return BarTooltipItem(
								rod.toY.round().toString(),
								TextStyle(
									color: rod.color, // Match text color to bar color
									fontWeight: FontWeight.bold,
									fontSize: 10,
								),
							);
						},
					),
				),
				barGroups: List.generate(12, (i) {
					return BarChartGroupData(
						x: i,
						// Force tooltips to show for both rods (0 and 1)
						showingTooltipIndicators: [0, 1],
						barRods: [
							BarChartRodData(
								toY: sData[i].toDouble(),
								color: Colors.blueAccent.withOpacity(0.7),
								width: 8,
								borderRadius: BorderRadius.circular(4),
							),
							BarChartRodData(
								toY: cData[i].toDouble(),
								color: Colors.greenAccent.shade400,
								width: 8,
								borderRadius: BorderRadius.circular(4),
							),
						],
					);
				}),
				titlesData: FlTitlesData(
					bottomTitles: AxisTitles(
						sideTitles: SideTitles(
							showTitles: true,
							getTitlesWidget: (v, m) {
								if (v % 2 != 0) return const SizedBox.shrink();
								return Padding(
									padding: const EdgeInsets.only(top: 5),
									child: Text(
										DateFormat.MMM().format(DateTime(0, v.toInt() + 1)),
										style: TextStyle(
												color: Colors.grey[600],
												fontSize: 10,
												fontWeight: FontWeight.bold),
									),
								);
							},
						),
					),
					leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
					topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
					rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
				),
				borderData: FlBorderData(show: false),
				gridData: FlGridData(
					show: true,
					drawVerticalLine: false,
					horizontalInterval: 1,
					getDrawingHorizontalLine: (v) =>
							FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
				),
			),
		);
	}

	Widget _buildModernPieChart(List<Goal> goals) {
		final map = <String, int>{};
		for (var cat in _goalCategories) map[cat] = 0;
		for (var g in goals) map[g.category] = (map[g.category] ?? 0) + 1;

		// Calculate Total for Percentage
		final total = goals.length;

		return Row(
			children: [
				Expanded(
					flex: 3,
					child: SizedBox(
						height: 200,
						child: PieChart(
							PieChartData(
								sectionsSpace: 2,
								centerSpaceRadius: 40,
								sections: map.entries.where((e) => e.value > 0).map((e) {
									final color = _pastelColorFor(e.key);
									// Calculate Percentage
									final percentage = total == 0 ? 0.0 : (e.value / total) * 100;

									return PieChartSectionData(
										value: e.value.toDouble(),
										// Display Percentage with % sign
										title: "${percentage.toStringAsFixed(0)}%",
										showTitle: true,
										titleStyle: const TextStyle(
												fontSize: 12,
												fontWeight: FontWeight.bold,
												color: Colors.white,
												shadows: [Shadow(color: Colors.black26, blurRadius: 2)]
										),
										color: color,
										radius: 50,
									);
								}).toList(),
							),
						),
					),
				),
				// Legend stays the same (shows raw count for detailed context)
				Expanded(
					flex: 2,
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: map.entries.where((e) => e.value > 0).map((e) {
							return Padding(
								padding: const EdgeInsets.symmetric(vertical: 4.0),
								child: Row(
									children: [
										CircleAvatar(radius: 4, backgroundColor: _pastelColorFor(e.key)),
										const SizedBox(width: 8),
										Expanded(
											child: Text(
												e.key,
												style: const TextStyle(fontSize: 11, color: Colors.grey),
												overflow: TextOverflow.ellipsis,
											),
										),
										Text("${e.value}",
												style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
									],
								),
							);
						}).toList(),
					),
				)
			],
		);
	}

	Widget _buildRadarChart(List<Goal> total, List<Goal> done) {
		final perf = <String, double>{};
		for (final c in _goalCategories) {
			final t = total.where((g) => g.category == c).length;
			final d = done.where((g) => g.category == c).length;
			// Calculate Ratio (Complete / All)
			perf[c] = t == 0 ? 0.0 : d / t;
		}

		return RadarChart(RadarChartData(
			// 1. Set max value to 1.0 (100%) explicitly so the scale is consistent
			radarTouchData: RadarTouchData(enabled: false),

			// 2. Configure Ticks (The values inside the chart)
			tickCount: 4, // 0.2, 0.4, 0.6, 0.8
			ticksTextStyle: const TextStyle(
					color: Colors.grey,
					fontSize: 10,
					fontWeight: FontWeight.bold
			),
			gridBorderData: BorderSide(color: Colors.grey.withOpacity(0.2)),

			// 3. Category Names (Clean, no numbers)
			titlePositionPercentageOffset: 0.1,
			titleTextStyle: const TextStyle(
					fontSize: 10,
					color: Colors.black87,
					fontWeight: FontWeight.w600
			),
			getTitle: (index, angle) {
				// Just the name, formatted with a line break
				return RadarChartTitle(
						text: _goalCategories[index].replaceAll(" & ", "\n& "),
						angle: angle
				);
			},

			dataSets: [
				RadarDataSet(
					fillColor: DashboardTheme.accentPurple.withOpacity(0.2),
					borderColor: DashboardTheme.accentPurple,
					entryRadius: 3,
					dataEntries: perf.values.map((e) => RadarEntry(value: e)).toList(),
				)
			],
		));
	}
}

/// ---------------------------------------------------------------------------
///  HELPER WIDGETS (The visual polish)
/// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
	final String title;
	final IconData icon;
	const _SectionHeader({required this.title, required this.icon});

	@override
	Widget build(BuildContext context) {
		return Row(
			children: [
				Container(
					padding: const EdgeInsets.all(8),
					decoration: BoxDecoration(
						color: DashboardTheme.primaryDeep.withOpacity(0.1),
						borderRadius: BorderRadius.circular(8),
					),
					child: Icon(icon, size: 18, color: DashboardTheme.primaryDeep),
				),
				const SizedBox(width: 12),
				Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2A2D3E))),
			],
		);
	}
}

class _ChartContainer extends StatelessWidget {
	final Widget child;
	final double? height;
	const _ChartContainer({required this.child, this.height});

	@override
	Widget build(BuildContext context) {
		return Container(
			height: height ?? 280,
			padding: const EdgeInsets.all(20),
			decoration: DashboardTheme.cardDecoration,
			child: child,
		);
	}
}

class _HeroStatCard extends StatelessWidget {
	final String title;
	final String value;
	final String? subtitle;
	final IconData icon;
	final Color color;
	final int delay;

	const _HeroStatCard({
		required this.title,
		required this.value,
		this.subtitle,
		required this.icon,
		required this.color,
		required this.delay,
	});

	@override
	Widget build(BuildContext context) {
		return TweenAnimationBuilder<double>(
			tween: Tween(begin: 0, end: 1),
			duration: Duration(milliseconds: 600 + delay),
			curve: Curves.easeOutBack,
			builder: (context, val, child) {
				return Transform.scale(
					scale: val,
					child: Container(
						padding: const EdgeInsets.all(16),
						decoration: BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.circular(20),
							boxShadow: [
								BoxShadow(
									color: color.withOpacity(0.15),
									blurRadius: 15,
									offset: const Offset(0, 8),
								),
							],
						),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								Row(
									mainAxisAlignment: MainAxisAlignment.spaceBetween,
									children: [
										Icon(icon, color: color, size: 24),
										if(subtitle != null)
											Text(subtitle!, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
									],
								),
								Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87)),
										Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
									],
								)
							],
						),
					),
				);
			},
		);
	}
}

class _ModernFilterBar extends StatelessWidget {
	// Pass in all your state variables and callbacks here
	final String mode;
	final List<int> years;
	final int? selectedYear;
	final int? selectedQuarterYear;
	final String selectedQuarter;
	final int? selectedMonthYear;
	final int selectedMonth;
	final DateTimeRange? customRange;

	final ValueChanged<String> onModeChanged;
	final ValueChanged<int?> onYearChanged;
	final ValueChanged<int?> onQYearChanged;
	final ValueChanged<String> onQuarterChanged;
	final ValueChanged<int?> onMYearChanged;
	final ValueChanged<int?> onMonthChanged;
	final VoidCallback onDateRangeTap;

	const _ModernFilterBar({
		required this.mode,
		required this.years,
		required this.onModeChanged,
		this.selectedYear,
		this.selectedQuarterYear,
		required this.selectedQuarter,
		this.selectedMonthYear,
		required this.selectedMonth,
		this.customRange,
		required this.onYearChanged,
		required this.onQYearChanged,
		required this.onQuarterChanged,
		required this.onMYearChanged,
		required this.onMonthChanged,
		required this.onDateRangeTap,
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(16),
				boxShadow: [
					BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
				],
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					SingleChildScrollView(
						scrollDirection: Axis.horizontal,
						child: Row(
							children: ["All Time", "Year", "Quarter", "Month", "Custom"].map((m) {
								final isSelected = mode == m;
								return Padding(
									padding: const EdgeInsets.only(right: 8),
									child: ChoiceChip(
										label: Text(m),
										selected: isSelected,
										selectedColor: DashboardTheme.primaryDeep,
										labelStyle: TextStyle(
												color: isSelected ? Colors.white : Colors.black87,
												fontSize: 12
										),
										onSelected: (_) => onModeChanged(m),
										backgroundColor: Colors.grey[100],
										side: BorderSide.none,
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
									),
								);
							}).toList(),
						),
					),

					// Secondary Filters (Only show if needed)
					if (mode != "All Time") ...[
						const Divider(height: 20),
						_buildSubFilter(),
					]
				],
			),
		);
	}

	Widget _buildSubFilter() {
		if (mode == "Year") {
			return _Dropdown(
				value: selectedYear,
				items: years,
				onChanged: onYearChanged,
				label: "Year",
			);
		}
		if (mode == "Quarter") {
			return Row(
				children: [
					Expanded(child: _Dropdown(value: selectedQuarterYear, items: years, onChanged: onQYearChanged, label: "Year")),
					const SizedBox(width: 10),
					Expanded(child: _Dropdown(value: selectedQuarter, items: const ["Q1","Q2","Q3","Q4"], onChanged: (v) => onQuarterChanged(v as String), label: "Quarter")),
				],
			);
		}
		if (mode == "Month") {
			return Row(
				children: [
					Expanded(child: _Dropdown(value: selectedMonthYear, items: years, onChanged: onMYearChanged, label: "Year")),
					const SizedBox(width: 10),
					Expanded(child: _Dropdown(
							value: selectedMonth,
							items: List.generate(12, (i) => i + 1),
							displayMap: (v) => DateFormat.MMM().format(DateTime(0, v as int)),
							onChanged: onMonthChanged,
							label: "Month"
					)),
				],
			);
		}
		if (mode == "Custom") {
			return InkWell(
				onTap: onDateRangeTap,
				child: Container(
					padding: const EdgeInsets.all(12),
					decoration: BoxDecoration(
						border: Border.all(color: Colors.grey.shade300),
						borderRadius: BorderRadius.circular(8),
					),
					child: Row(
						children: [
							const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
							const SizedBox(width: 8),
							Text(
								customRange == null
										? "Select Date Range"
										: "${DateFormat.MMMd().format(customRange!.start)} - ${DateFormat.MMMd().format(customRange!.end)}",
								style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
							),
						],
					),
				),
			);
		}
		return const SizedBox.shrink();
	}
}

class _Dropdown<T> extends StatelessWidget {
	// Allow value to be nullable (T?) to match DropdownButton's behavior
	final T? value;
	// Ensure items match the generic type T
	final List<T> items;
	final Function(T?) onChanged;
	final String label;
	final String Function(T)? displayMap;

	const _Dropdown({
		super.key,
		required this.value,
		required this.items,
		required this.onChanged,
		required this.label,
		this.displayMap,
	});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
			decoration: BoxDecoration(
				color: Colors.grey[50],
				borderRadius: BorderRadius.circular(12),
				border: Border.all(color: Colors.grey.shade200),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					// Tiny label for better UX
					Text(
						label,
						style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
					),
					SizedBox(
						height: 30,
						child: DropdownButtonHideUnderline(
							child: DropdownButton<T>(
								value: value,
								isExpanded: true,
								icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black54),
								style: const TextStyle(
										color: Colors.black87,
										fontSize: 14,
										fontWeight: FontWeight.w600
								),
								// Safely map items. If T is int, e is int.
								items: items.map((e) {
									return DropdownMenuItem<T>(
										value: e,
										child: Text(
											displayMap != null ? displayMap!(e) : "$e",
											style: const TextStyle(fontSize: 13),
										),
									);
								}).toList(),
								onChanged: onChanged,
							),
						),
					),
				],
			),
		);
	}
}

Color _pastelColorFor(String category) {
	switch (category) {
		case 'Health & Wellness': return const Color(0xFF4FC3F7); // Light Blue
		case 'Career & Finance': return const Color(0xFF81C784); // Light Green
		case 'Education & Learning': return const Color(0xFFFFB74D); // Orange
		case 'Relationships & Community': return const Color(0xFFE57373); // Red
		case 'Personal Growth': return const Color(0xFFBA68C8); // Purple
		default: return Colors.grey;
	}
}