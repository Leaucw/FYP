import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/life_stage.dart';
import '../models/goal.dart';
import '../models/achievement.dart';

import '../services/life_stage_service.dart';
import '../services/goal_service.dart';
import '../services/achievement_service.dart';

import '../theme/app_colors.dart';

class TimelineScreen extends StatefulWidget {
	const TimelineScreen({super.key});

	@override
	State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
		with SingleTickerProviderStateMixin {
	final _auth = FirebaseAuth.instance;
	final _stages = LifeStageService(db: FirebaseFirestore.instance);
	final _goals = GoalService(db: FirebaseFirestore.instance);
	final _achievements = AchievementService(db: FirebaseFirestore.instance);

	late AnimationController _controller;

	@override
	void initState() {
		super.initState();
		_controller = AnimationController(
			vsync: this,
			duration: const Duration(milliseconds: 800),
		);
	}

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	// ---------------------------------------------------------------------------
	// DIALOGS
	// ---------------------------------------------------------------------------
	Future<void> _showAddEditDialog(BuildContext context, {LifeStage? existing}) async {
		final nameCtrl = TextEditingController(text: existing?.name ?? '');
		DateTime? startDate = existing?.startDate;
		DateTime? endDate = existing?.endDate;
		Color selectedColor = existing != null ? Color(existing.colorValue) : Colors.blueAccent;

		await showDialog(
			context: context,
			builder: (_) => StatefulBuilder(
				builder: (context, setModalState) {
					return AlertDialog(
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
						title: Text(existing == null ? "New Life Stage" : "Edit Life Stage",
								style: const TextStyle(fontWeight: FontWeight.bold)),
						content: SingleChildScrollView(
							child: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									TextField(
										controller: nameCtrl,
										decoration: InputDecoration(
											labelText: "Life Stage Name",
											border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
											filled: true,
											fillColor: Colors.grey.shade50,
										),
									),
									const SizedBox(height: 16),
									Row(
										children: [
											Expanded(
												child: _DateButton(
													label: "Start",
													date: startDate,
													onTap: () async {
														final picked = await showDatePicker(
															context: context,
															initialDate: startDate ?? DateTime.now(),
															firstDate: DateTime(1900),
															lastDate: DateTime(2100),
														);
														if (picked != null) setModalState(() => startDate = picked);
													},
												),
											),
											const SizedBox(width: 10),
											Expanded(
												child: _DateButton(
													label: "End",
													date: endDate,
													onTap: () async {
														final picked = await showDatePicker(
															context: context,
															initialDate: endDate ?? DateTime.now(),
															firstDate: DateTime(1900),
															lastDate: DateTime(2100),
														);
														if (picked != null) setModalState(() => endDate = picked);
													},
												),
											),
										],
									),
									const SizedBox(height: 20),
									Row(
										children: [
											const Text("Theme Color:", style: TextStyle(fontWeight: FontWeight.w600)),
											const Spacer(),
											GestureDetector(
												onTap: () async {
													await _showColorPicker(context, selectedColor, (c) {
														setModalState(() => selectedColor = c);
													});
												},
												child: Container(
													width: 36, height: 36,
													decoration: BoxDecoration(
														color: selectedColor,
														shape: BoxShape.circle,
														boxShadow: [BoxShadow(color: selectedColor.withOpacity(0.4), blurRadius: 8)],
														border: Border.all(color: Colors.grey.shade300, width: 2),
													),
												),
											),
										],
									),
								],
							),
						),
						actions: [
							TextButton(child: const Text("Cancel", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(context)),
							if(existing != null)
								TextButton(child: const Text("Delete", style: TextStyle(color: Colors.red)), onPressed: () {
									_stages.delete(_auth.currentUser!.uid, existing.id);
									Navigator.pop(context);
								}),
							ElevatedButton(
								style: ElevatedButton.styleFrom(
									backgroundColor: AppColors.primary,
									foregroundColor: Colors.white,
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
								),
								child: const Text("Save Life Stage"),
								onPressed: () {
									if (nameCtrl.text.isNotEmpty) {
										final data = LifeStage(
											id: existing?.id ?? '',
											userId: _auth.currentUser!.uid,
											name: nameCtrl.text.trim(),
											startDate: startDate,
											endDate: endDate,
											sortOrder: existing?.sortOrder ?? DateTime.now().millisecondsSinceEpoch,
											colorValue: selectedColor.value,
										);
										if (existing == null) {
											_stages.create(_auth.currentUser!.uid, data);
										} else {
											_stages.update(_auth.currentUser!.uid, data);
										}
										Navigator.pop(context);
									}
								},
							)
						],
					);
				},
			),
		);
	}

	Future<void> _showColorPicker(BuildContext context, Color initial, Function(Color) onSelect) async {
		await showDialog(
			context: context,
			builder: (_) => AlertDialog(
				contentPadding: const EdgeInsets.all(0),
				content: SizedBox(
					width: 320,
					height: 540,
					child: ColorPickerWidget(initialColor: initial, onColorChanged: (c) => initial = c),
				),
				actions: [
					TextButton(child: const Text("Done"), onPressed: () { onSelect(initial); Navigator.pop(context); }),
				],
			),
		);
	}

	// ---------------------------------------------------------------------------
	// MAIN BUILD
	// ---------------------------------------------------------------------------
	@override
	Widget build(BuildContext context) {
		final user = _auth.currentUser;
		if (user == null) return const Scaffold(body: Center(child: Text("Please sign in")));

		return Scaffold(
			backgroundColor: const Color(0xFFF8F9FC),
			// REVERTED: Standard App Bar
				appBar: AppBar(
					elevation: 0,
					backgroundColor: AppColors.primary,
					foregroundColor: Colors.white,
					centerTitle: true,

					title: Row(
						mainAxisSize: MainAxisSize.min, // Keeps title centered
						children: [
							Icon(
								Icons.timeline_rounded,  // ← Your icon
								color: Colors.white,
								size: 22,
							),
							const SizedBox(width: 8),
							const Text(
								"Life Timeline",
								style: TextStyle(
									fontSize: 20,
									fontWeight: FontWeight.w600,
									color: Colors.white,
								),
							),
						],
					),

					actions: [
						IconButton(
							icon: const Icon(Icons.add),
							onPressed: () => _showAddEditDialog(context),
						),
					],

					// Background icon
					flexibleSpace: Stack(
						children: [
							Positioned(
								right: -20,
								bottom: -20,
								child: Icon(
									Icons.analytics,
									size: 150,
									color: Colors.white.withOpacity(0.05),
								),
							),
						],
					),
				),



				body: StreamBuilder<List<LifeStage>>(
				stream: _stages.stream(user.uid),
				builder: (context, stageSnap) {
					if (!stageSnap.hasData) return const Center(child: CircularProgressIndicator());

					return StreamBuilder<List<Goal>>(
						stream: _goals.streamGoals(user.uid),
						builder: (context, goalSnap) {
							if (!goalSnap.hasData) return const SizedBox();

							return StreamBuilder<List<Achievement>>(
								stream: _achievements.stream(user.uid),
								builder: (context, achSnap) {
									if (!achSnap.hasData) return const SizedBox();

									_controller.forward(from: 0);

									final stages = stageSnap.data!
										..sort((a, b) {
											final aStart = a.startDate ?? DateTime.fromMillisecondsSinceEpoch(a.sortOrder);
											final bStart = b.startDate ?? DateTime.fromMillisecondsSinceEpoch(b.sortOrder);
											return aStart.compareTo(bStart);
										});

									final goals = goalSnap.data!;
									final achievements = achSnap.data!;
									final completedGoals = goals.where((g) => g.status == GoalStatus.completed).toList();

									final List<Widget> timelineWidgets = [];
									final assignedGoalIds = <String>{};
									final assignedAchIds = <String>{};

									if (stages.isEmpty) return _buildEmptyState();

									// 1. Build Stages
									for (int i = 0; i < stages.length; i++) {
										final stage = stages[i];
										final stageColor = Color(stage.colorValue);

										final stageEntries = _getEntriesForStage(stage, completedGoals, achievements, assignedGoalIds, assignedAchIds);

										// Header
										timelineWidgets.add(
												_AnimatedSlideItem(
													index: i,
													controller: _controller,
													child: Padding(
														padding: const EdgeInsets.only(top: 24.0, bottom: 12),
														child: _StageHeader(stage: stage, color: stageColor, onEdit: () => _showAddEditDialog(context, existing: stage)),
													),
												)
										);

										// Items
										if (stageEntries.isEmpty) {
											timelineWidgets.add(_buildEmptyStageMsg());
										} else {
											for (int j = 0; j < stageEntries.length; j++) {
												timelineWidgets.add(
														_AnimatedSlideItem(
															index: i + j + 2,
															controller: _controller,
															child: _TimelineNode(
																entry: stageEntries[j],
																color: stageColor,
																isLastInStage: j == stageEntries.length - 1,
															),
														)
												);
											}
										}
									}

									// 2. Unassigned
									final unassignedEntries = _getUnassignedEntries(completedGoals, achievements, assignedGoalIds, assignedAchIds);

									if (unassignedEntries.isNotEmpty) {
										timelineWidgets.add(const Padding(
											padding: EdgeInsets.only(top: 30, bottom: 10),
											child: Center(child: Text("Other Memories", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
										));
										for(var entry in unassignedEntries) {
											timelineWidgets.add(_TimelineNode(entry: entry, color: Colors.grey, isLastInStage: false));
										}
									}

									timelineWidgets.add(const SizedBox(height: 80));

									return ListView(
										padding: const EdgeInsets.symmetric(horizontal: 20),
										children: timelineWidgets,
									);
								},
							);
						},
					);
				},
			),
		);
	}

	List<_TimelineEntry> _getEntriesForStage(LifeStage stage, List<Goal> goals, List<Achievement> achs, Set<String> assignedG, Set<String> assignedA) {
		final gList = goals.where((g) {
			final d = g.completedAt ?? g.endDate ?? g.startDate ?? g.createdAt;
			if (stage.startDate != null && d.isBefore(stage.startDate!)) return false;
			if (stage.endDate != null && d.isAfter(stage.endDate!)) return false;
			return true;
		}).toList();
		assignedG.addAll(gList.map((e) => e.id));

		final aList = achs.where((a) {
			if (a.lifeStageId == stage.id) return true;
			if (stage.startDate != null && a.date.isBefore(stage.startDate!)) return false;
			if (stage.endDate != null && a.date.isAfter(stage.endDate!)) return false;
			return true;
		}).toList();
		assignedA.addAll(aList.map((e) => e.id));

		final entries = <_TimelineEntry>[
			...gList.map((g) => _TimelineEntry(date: g.completedAt ?? g.createdAt, title: g.title, subtitle: g.category, isAchievement: false)),
			...aList.map((a) => _TimelineEntry(date: a.date, title: a.title, subtitle: a.category, isAchievement: true)),
		]..sort((a, b) => a.date.compareTo(b.date));
		return entries;
	}

	List<_TimelineEntry> _getUnassignedEntries(List<Goal> goals, List<Achievement> achs, Set<String> assignedG, Set<String> assignedA) {
		final gList = goals.where((g) => !assignedG.contains(g.id));
		final aList = achs.where((a) => !assignedA.contains(a.id));
		return [
			...gList.map((g) => _TimelineEntry(date: g.completedAt ?? g.createdAt, title: g.title, subtitle: g.category, isAchievement: false)),
			...aList.map((a) => _TimelineEntry(date: a.date, title: a.title, subtitle: a.category, isAchievement: true)),
		]..sort((a, b) => a.date.compareTo(b.date));
	}

	Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.timeline, size: 64, color: Colors.grey.shade300), const Text("Start your journey", style: TextStyle(color: Colors.grey))]));
	Widget _buildEmptyStageMsg() => Padding(padding: const EdgeInsets.only(left: 40, bottom: 20), child: Text("No events recorded yet", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade400)));
}

// -----------------------------------------------------------------------------
// COMPONENTS: HEADER, NODE, ANIMATION, HELPERS
// -----------------------------------------------------------------------------
class _StageHeader extends StatelessWidget {
	final LifeStage stage;
	final Color color;
	final VoidCallback onEdit;
	const _StageHeader({required this.stage, required this.color, required this.onEdit});

	@override
	Widget build(BuildContext context) {
		return GestureDetector(
			onTap: onEdit,
			child: Container(
				padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
				decoration: BoxDecoration(
					gradient: LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
					borderRadius: BorderRadius.circular(16),
					boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
				),
				child: Row(
					children: [
						Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.auto_stories, color: Colors.white, size: 20)),
						const SizedBox(width: 16),
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(stage.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
									const SizedBox(height: 4),
									Text("${_formatDate(stage.startDate)} — ${_formatDate(stage.endDate)}", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
								],
							),
						),
						const Icon(Icons.edit, color: Colors.white70, size: 18),
					],
				),
			),
		);
	}
}

class _TimelineNode extends StatelessWidget {
	final _TimelineEntry entry;
	final Color color;
	final bool isLastInStage;
	const _TimelineNode({required this.entry, required this.color, required this.isLastInStage});

	@override
	Widget build(BuildContext context) {
		return IntrinsicHeight(
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					SizedBox(
						width: 60,
						child: Padding(
							padding: const EdgeInsets.only(top: 16.0, right: 8),
							child: Text(DateFormat("MMM yyyy").format(entry.date), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500, height: 1.2)),
						),
					),
					Column(
						children: [
							Expanded(flex: 1, child: Container(width: 2, color: Colors.grey.shade200)),
							Container(
								margin: const EdgeInsets.symmetric(vertical: 4), width: 14, height: 14,
								decoration: BoxDecoration(
										color: entry.isAchievement ? Colors.amber : Colors.white,
										border: Border.all(color: entry.isAchievement ? Colors.amber : color, width: 2.5),
										shape: BoxShape.circle,
										boxShadow: [if(entry.isAchievement) BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 6)]
								),
							),
							Expanded(flex: 5, child: isLastInStage
									? Container(width: 2, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.grey.shade200, Colors.transparent])))
									: Container(width: 2, color: Colors.grey.shade200)),
						],
					),
					const SizedBox(width: 16),
					Expanded(
						child: Container(
							margin: const EdgeInsets.only(bottom: 16, top: 4),
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(14),
								border: Border.all(color: Colors.grey.shade100),
								boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))],
							),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(children: [
										if (entry.isAchievement) ...[const Icon(Icons.emoji_events_rounded, size: 16, color: Colors.amber), const SizedBox(width: 6)],
										Expanded(child: Text(entry.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87))),
									]),
									if (entry.subtitle.isNotEmpty) ...[const SizedBox(height: 4), Text(entry.subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))]
								],
							),
						),
					),
				],
			),
		);
	}
}

class _AnimatedSlideItem extends StatelessWidget {
	final int index;
	final AnimationController controller;
	final Widget child;
	const _AnimatedSlideItem({required this.index, required this.controller, required this.child});

	@override
	Widget build(BuildContext context) {
		return AnimatedBuilder(
			animation: controller,
			builder: (context, child) {
				final delay = (index * 0.1).clamp(0.0, 0.5);
				final animation = CurvedAnimation(parent: controller, curve: Interval(delay, 1.0, curve: Curves.easeOutQuart));
				return Opacity(opacity: animation.value, child: Transform.translate(offset: Offset(0, 30 * (1 - animation.value)), child: child));
			},
			child: child,
		);
	}
}

class _DateButton extends StatelessWidget {
	final String label;
	final DateTime? date;
	final VoidCallback onTap;
	const _DateButton({required this.label, this.date, required this.onTap});
	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: onTap, borderRadius: BorderRadius.circular(12),
			child: Container(
				padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
				decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
				child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), const SizedBox(height: 4), Text(date == null ? "Select" : DateFormat("MMM yyyy").format(date!), style: const TextStyle(fontWeight: FontWeight.w600))]),
			),
		);
	}
}

String _formatDate(DateTime? d) => d == null ? "Present" : DateFormat("MMM yyyy").format(d);

class _TimelineEntry {
	final DateTime date;
	final String title;
	final String subtitle;
	final bool isAchievement;
	_TimelineEntry({required this.date, required this.title, required this.subtitle, required this.isAchievement});
}

// -----------------------------------------------------------------------------
// COLOR PICKER (PRESETS + RGB SLIDERS)
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// COLOR PICKER (SPECTRUM + PRESETS + RGB SLIDERS)
// -----------------------------------------------------------------------------
class ColorPickerWidget extends StatefulWidget {
	final Color initialColor;
	final Function(Color) onColorChanged;
	const ColorPickerWidget({super.key, required this.initialColor, required this.onColorChanged});
	@override
	State<ColorPickerWidget> createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget> {
	late Color _color;

	@override
	void initState() {
		super.initState();
		_color = widget.initialColor;
	}

	final List<Color> _presets = [
		const Color(0xFF6C63FF), const Color(0xFFFF6584), const Color(0xFF38E54D),
		const Color(0xFFFFC700), const Color(0xFF00D2FC), const Color(0xFF9A55FF),
		const Color(0xFFFF914D), const Color(0xFF434343),
	];

	void _updateColor(Color c) {
		setState(() => _color = c);
		widget.onColorChanged(c);
	}

	// Calculate color from the gradient bar position
	void _onSpectrumPan(double localDx, double width) {
		// Clamp position between 0.0 and 1.0
		final double position = (localDx / width).clamp(0.0, 1.0);

		// Convert position to Hue (0 to 360)
		final double hue = position * 360;

		// Create color from Hue, keeping Saturation and Value at max for vibrant colors
		final Color newColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

		_updateColor(newColor);
	}

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.all(20.0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Text("Preview", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
					const SizedBox(height: 8),
					// PREVIEW BOX
					Container(
						height: 50, width: double.infinity,
						decoration: BoxDecoration(
								color: _color,
								borderRadius: BorderRadius.circular(12),
								border: Border.all(color: Colors.grey.shade300)
						),
						alignment: Alignment.center,
						child: Text(
							"RGB(${_color.red}, ${_color.green}, ${_color.blue})",
							style: TextStyle(
									fontWeight: FontWeight.bold,
									color: (_color.red + _color.green + _color.blue > 400) ? Colors.black54 : Colors.white70
							),
						),
					),
					const SizedBox(height: 20),

					// --- NEW: SPECTRUM PALETTE ---
					const Text("Color Palette", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
					const SizedBox(height: 8),
					LayoutBuilder(
							builder: (context, constraints) {
								return GestureDetector(
									onPanUpdate: (details) => _onSpectrumPan(details.localPosition.dx, constraints.maxWidth),
									onTapDown: (details) => _onSpectrumPan(details.localPosition.dx, constraints.maxWidth),
									child: Container(
										height: 40,
										width: double.infinity,
										decoration: BoxDecoration(
											borderRadius: BorderRadius.circular(12),
											border: Border.all(color: Colors.grey.shade300),
											gradient: const LinearGradient(
												colors: [
													Colors.red,
													Colors.yellow,
													Colors.green,
													Colors.cyan,
													Colors.blue,
													Colors.purpleAccent,
													Colors.red,
												],
											),
										),
										child: CustomPaint(
											painter: _SliderIndicatorPainter(_color),
										),
									),
								);
							}
					),
					const SizedBox(height: 20),

					// PRESETS
					const Text("Quick Select", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
					const SizedBox(height: 10),
					Wrap(
						spacing: 10, runSpacing: 10,
						children: _presets.map((c) => GestureDetector(
							onTap: () => _updateColor(c),
							child: Container(
								width: 40, height: 40,
								decoration: BoxDecoration(
										color: c, shape: BoxShape.circle,
										border: _color.value == c.value ? Border.all(color: Colors.black, width: 3) : null,
										boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 5)]
								),
							),
						)).toList(),
					),

					const Divider(height: 30),

					// RGB SLIDERS
					const Text("Fine Tune (RGB)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
					const SizedBox(height: 4),
					_rgbSlider("R", _color.red, Colors.red, (v) => _updateColor(_color.withRed(v.toInt()))),
					_rgbSlider("G", _color.green, Colors.green, (v) => _updateColor(_color.withGreen(v.toInt()))),
					_rgbSlider("B", _color.blue, Colors.blue, (v) => _updateColor(_color.withBlue(v.toInt()))),
				],
			),
		);
	}

	Widget _rgbSlider(String label, int value, Color color, ValueChanged<double> onChanged) {
		return Row(
			children: [
				SizedBox(width: 20, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
				Expanded(
					child: SliderTheme(
						data: SliderTheme.of(context).copyWith(
							activeTrackColor: color,
							thumbColor: color,
							inactiveTrackColor: color.withOpacity(0.2),
							trackHeight: 4,
							thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
						),
						child: Slider(
							value: value.toDouble(),
							min: 0, max: 255,
							onChanged: onChanged,
						),
					),
				),
				SizedBox(width: 35, child: Text("$value", textAlign: TextAlign.end, style: const TextStyle(fontSize: 12))),
			],
		);
	}
}

// Helper painter to show where the user is clicking on the spectrum
class _SliderIndicatorPainter extends CustomPainter {
	final Color color;
	_SliderIndicatorPainter(this.color);

	@override
	void paint(Canvas canvas, Size size) {
		// Convert current color to HSV to find X position
		final hsv = HSVColor.fromColor(color);
		final double x = (hsv.hue / 360) * size.width;

		final Paint paint = Paint()
			..color = Colors.white
			..style = PaintingStyle.stroke
			..strokeWidth = 3;

		final Paint shadowPaint = Paint()
			..color = Colors.black.withOpacity(0.3)
			..style = PaintingStyle.stroke
			..strokeWidth = 4;

		// Draw a simple indicator circle
		canvas.drawCircle(Offset(x, size.height / 2), 14, shadowPaint);
		canvas.drawCircle(Offset(x, size.height / 2), 14, paint);
	}

	@override
	bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}