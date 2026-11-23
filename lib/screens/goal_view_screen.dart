import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/screens/share_goal_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/goal.dart';
import '../models/achievement.dart';
import '../services/goal_service.dart';
import '../services/achievement_service.dart';
import '../theme/app_colors.dart';

class GoalViewScreen extends StatefulWidget {
	final String goalId;
	final String userId;
	const GoalViewScreen({super.key, required this.goalId, required this.userId});

	@override
	State<GoalViewScreen> createState() => _GoalViewScreenState();
}

class _GoalViewScreenState extends State<GoalViewScreen> {
	final _goals = GoalService(db: FirebaseFirestore.instance);
	final _achievements = AchievementService(db: FirebaseFirestore.instance);

	Goal? _goal;
	bool _loading = true;

	@override
	void initState() {
		super.initState();
		_load();
	}

	Future<void> _load() async {
		setState(() => _loading = true);
		final doc = await FirebaseFirestore.instance
				.collection('users')
				.doc(widget.userId)
				.collection('goals')
				.doc(widget.goalId)
				.get();

		if (!doc.exists) {
			if (mounted) Navigator.pop(context);
			return;
		}

		final goal = Goal.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);

		// Logic to handle overdue items... (Same as your original logic)
		if (goal.status != GoalStatus.completed &&
				goal.endDate != null &&
				DateTime.now().isAfter(goal.endDate!) &&
				goal.status != GoalStatus.missed) {
			await _goals.updateGoal(widget.userId,
					goal.copyWith(status: GoalStatus.missed, updatedAt: DateTime.now()));
			if (mounted) {
				setState(() {
					_goal = goal.copyWith(status: GoalStatus.missed);
					_loading = false;
				});
			}
			return;
		}

		setState(() {
			_goal = goal;
			_loading = false;
		});
	}

	// --- UI HELPERS ---

	Color _getCategoryColor(String cat) {
		// Returns a subtle pastel color based on category
		switch (cat) {
			case "Health & Wellness": return Colors.green.shade50;
			case "Career & Finance": return Colors.blue.shade50;
			case "Education & Learning": return Colors.orange.shade50;
			case "Relationships": return Colors.pink.shade50;
			default: return Colors.purple.shade50;
		}
	}

	Color _getCategoryAccent(String cat) {
		switch (cat) {
			case "Health & Wellness": return Colors.green;
			case "Career & Finance": return Colors.blue;
			case "Education & Learning": return Colors.orange;
			case "Relationships": return Colors.pink;
			default: return Colors.purple;
		}
	}

	IconData _iconForCategory(String cat) {
		switch (cat) {
			case "Health & Wellness": return Icons.spa_rounded;
			case "Career & Finance": return Icons.account_balance_wallet_rounded;
			case "Education & Learning": return Icons.school_rounded;
			case "Relationships": return Icons.favorite_rounded;
			default: return Icons.star_rounded;
		}
	}

	double _calculateProgress() {
		if (_goal == null || _goal!.subGoals.isEmpty) return 0.0;
		final completed = _goal!.subGoals.where((s) => s.completed).length;
		return completed / _goal!.subGoals.length;
	}

	// --- LOGIC METHODS (Kept mostly same) ---

	Future<void> _toggleSub(String id, bool value) async {
		if (_goal == null) return;
		final target = _goal!.subGoals.firstWhere((e) => e.id == id).copyWith(completed: value);
		await _goals.updateSubGoal(widget.userId, widget.goalId, target);
		await _load();
	}

	Future<void> _addSub() async {
		final ctrl = TextEditingController();
		await showDialog(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text("Add Step"),
				content: TextField(
					controller: ctrl,
					autofocus: true,
					decoration: const InputDecoration(
							hintText: "What is the sub goal?",
							border: OutlineInputBorder()),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
					ElevatedButton(
						onPressed: () async {
							if (ctrl.text.trim().isEmpty) return;
							final sub = SubGoal(
								id: const Uuid().v4(),
								title: ctrl.text.trim(),
								completed: false,
								dueDate: null,
							);
							await _goals.addSubGoal(widget.userId, widget.goalId, sub);
							if (mounted) Navigator.pop(context);
							await _load();
						},
						child: const Text("Add"),
					)
				],
			),
		);
	}

	Future<void> _markCompletedAsAchievement() async {
		// ... (Your original logic remains here)
		if (_goal == null) return;
		final g = _goal!;
		final confirm = await showDialog<bool>(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text("Celebrate Success?"),
				content: const Text("Convert this goal into an Achievement? It will move to your trophy case."),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
					ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Convert")),
				],
			),
		) ?? false;

		if (!confirm) return;

		final when = g.completedAt ?? g.endDate ?? DateTime.now();
		final now = DateTime.now();
		final a = Achievement(
			id: '', // will be replaced by Firestore doc ID
			userId: g.userId,
			title: g.title,
			description: g.description,
			date: when,
			category: g.category,
			associatedPeople: g.associatedPeople,
			lifeStageId: null,
			locationName: g.locationName,
			latitude: g.latitude,
			longitude: g.longitude,
			sourceGoalId: g.id,
			createdAt: now,
			updatedAt: now,

			// NEW FIELDS
			points: 0,           // will be recalculated by the service
			photoBase64: null,   // goals don’t have photos, so default null
		);

		await _achievements.create(widget.userId, a);
		await _goals.deleteGoal(widget.userId, g.id);
		if (!mounted) return;
		Navigator.pop(context);
	}

	void _markStatus(GoalStatus status) async {
		// ... (Your original logic)
		if (_goal == null) return;
		final g = _goal!;
		final now = DateTime.now();

		// Toggle logic
		if (status != GoalStatus.completed && g.status == GoalStatus.completed) {
			status = (g.endDate != null && now.isAfter(g.endDate!)) ? GoalStatus.missed : GoalStatus.inProgress;
		}

		await _goals.updateGoal(widget.userId, g.copyWith(
			status: status,
			completedAt: status == GoalStatus.completed ? (g.completedAt ?? DateTime.now()) : null,
			updatedAt: DateTime.now(),
		));
		await _load();
	}

	// --- WIDGETS ---

	Widget _buildTimelineStep(int index, SubGoal sub, bool isLast) {
		final isLocked = index > 0 && !_goal!.subGoals[index - 1].completed;
		final isCompleted = sub.completed;

		return IntrinsicHeight(
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					// Timeline Line & Dot
					SizedBox(
						width: 40,
						child: Column(
							children: [
								Container(
									width: 2,
									height: 20,
									color: index == 0 ? Colors.transparent : Colors.grey.shade300,
								),
								GestureDetector(
									onTap: isLocked ? null : () => _toggleSub(sub.id, !sub.completed),
									child: Container(
										width: 24,
										height: 24,
										decoration: BoxDecoration(
											color: isCompleted ? AppColors.primary : (isLocked ? Colors.grey.shade200 : Colors.white),
											shape: BoxShape.circle,
											border: Border.all(
												color: isLocked ? Colors.grey.shade300 : AppColors.primary,
												width: 2,
											),
										),
										child: Center(
											child: isLocked
													? Icon(Icons.lock, size: 14, color: Colors.grey.shade400)
													: (isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
										),
									),
								),
								Expanded(
									child: Container(
										width: 2,
										color: isLast ? Colors.transparent : Colors.grey.shade300,
									),
								),
							],
						),
					),
					const SizedBox(width: 12),
					// Content
					Expanded(
						child: Padding(
							padding: const EdgeInsets.only(bottom: 24.0),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									const SizedBox(height: 10), // Align text with dot
									Text(
										sub.title,
										style: TextStyle(
											fontSize: 16,
											decoration: isCompleted ? TextDecoration.lineThrough : null,
											color: isLocked
													? Colors.grey.shade400
													: (isCompleted ? Colors.grey.shade600 : AppColors.textPrimary),
											fontWeight: isCompleted ? FontWeight.normal : FontWeight.w600,
										),
									),
									if (isLocked)
										Text(
											"Complete previous step to unlock",
											style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
										),
								],
							),
						),
					),
				],
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		if (_loading || _goal == null) {
			return const Scaffold(body: Center(child: CircularProgressIndicator()));
		}

		final goal = _goal!;
		final progress = _calculateProgress();
		final accentColor = _getCategoryAccent(goal.category);
		final bgAccent = _getCategoryColor(goal.category);

		return Scaffold(
			backgroundColor: Colors.white,
			body: CustomScrollView(
				physics: const BouncingScrollPhysics(),
				slivers: [
					// 1. MODERN APP BAR
					SliverAppBar(
						expandedHeight: 200,
						pinned: true,
						backgroundColor: Colors.white,
						elevation: 0,
						actions: [
							IconButton(
								icon: const Icon(Icons.share_rounded, color: AppColors.primary),
								onPressed: () {
									if (_goal != null) {
										Navigator.push(
											context,
											MaterialPageRoute(
												builder: (_) => ShareGoalScreen(goal: _goal!),
											),
										);
									}
								},
							),
							const SizedBox(width: 8),
						],
						flexibleSpace: FlexibleSpaceBar(
							background: Container(
								decoration: BoxDecoration(
									gradient: LinearGradient(
										begin: Alignment.topCenter,
										end: Alignment.bottomCenter,
										colors: [bgAccent, Colors.white],
									),
								),
								child: Padding(
									padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													Container(
														padding: const EdgeInsets.all(8),
														decoration: BoxDecoration(
															color: Colors.white,
															shape: BoxShape.circle,
															boxShadow: [BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 8)],
														),
														child: Icon(_iconForCategory(goal.category), color: accentColor, size: 24),
													),
													const SizedBox(width: 12),
													Text(goal.category.toUpperCase(),
															style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 1.2)
													),
												],
											),
											const SizedBox(height: 12),
											Text(
												goal.title,
												maxLines: 2,
												overflow: TextOverflow.ellipsis,
												style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
											),
										],
									),
								),
							),
						),
					),

					SliverToBoxAdapter(
						child: Padding(
							padding: const EdgeInsets.symmetric(horizontal: 24),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									// 2. PROGRESS BAR
									Row(
										mainAxisAlignment: MainAxisAlignment.spaceBetween,
										children: [
											Text("Progress", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
											Text("${(progress * 100).toInt()}%", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
										],
									),
									const SizedBox(height: 8),
									ClipRRect(
										borderRadius: BorderRadius.circular(10),
										child: LinearProgressIndicator(
											value: progress,
											minHeight: 8,
											backgroundColor: Colors.grey.shade100,
											valueColor: AlwaysStoppedAnimation(accentColor),
										),
									),

									const SizedBox(height: 32),

									// 3. METADATA ROW (Date, People)
									Row(
										children: [
											Expanded(
												child: Container(
													padding: const EdgeInsets.all(12),
													decoration: BoxDecoration(
														color: Colors.grey.shade50,
														borderRadius: BorderRadius.circular(12),
														border: Border.all(color: Colors.grey.shade200),
													),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															const Text("DEADLINE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
															const SizedBox(height: 4),
															Text(
																goal.endDate != null ? DateFormat("d MMM yyyy").format(goal.endDate!) : "No Date",
																style: const TextStyle(fontWeight: FontWeight.w600),
															),
														],
													),
												),
											),
											const SizedBox(width: 12),
											if (goal.associatedPeople.isNotEmpty)
												Expanded(
													child: Container(
														padding: const EdgeInsets.all(12),
														decoration: BoxDecoration(
															color: Colors.grey.shade50,
															borderRadius: BorderRadius.circular(12),
															border: Border.all(color: Colors.grey.shade200),
														),
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																const Text("WITH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
																const SizedBox(height: 4),
																Text(
																	goal.associatedPeople.join(", "),
																	maxLines: 1,
																	overflow: TextOverflow.ellipsis,
																	style: const TextStyle(fontWeight: FontWeight.w600),
																),
															],
														),
													),
												),
										],
									),

									const SizedBox(height: 32),

									// 4. DESCRIPTION ("The Why")
									if (goal.description.isNotEmpty) ...[
										Text("The Why", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
										const SizedBox(height: 8),
										Text(
											goal.description,
											style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey.shade700),
										),
										const SizedBox(height: 32),
									],

									// 5. THE JOURNEY (Timeline)
									Row(
										mainAxisAlignment: MainAxisAlignment.spaceBetween,
										children: [
											Text("Sub Goals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
											IconButton(
												onPressed: _addSub,
												icon: const Icon(Icons.add_circle_outline),
												color: accentColor,
											)
										],
									),
									const SizedBox(height: 16),
									ListView.builder(
										shrinkWrap: true,
										physics: const NeverScrollableScrollPhysics(),
										itemCount: goal.subGoals.length,
										itemBuilder: (context, index) {
											return _buildTimelineStep(index, goal.subGoals[index], index == goal.subGoals.length - 1);
										},
									),
									if (goal.subGoals.isEmpty)
										Center(
											child: Padding(
												padding: const EdgeInsets.symmetric(vertical: 20),
												child: Text("No steps yet. Break it down!", style: TextStyle(color: Colors.grey.shade400)),
											),
										),

									const SizedBox(height: 32),

									// 6. LOCATION CARD (Visual)
									if (goal.locationName != null) ...[
										Text("Destination", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
										const SizedBox(height: 12),
										Container(
											width: double.infinity,
											padding: const EdgeInsets.all(16),
											decoration: BoxDecoration(
												color: Colors.white,
												borderRadius: BorderRadius.circular(16),
												boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))],
												border: Border.all(color: Colors.grey.shade100),
											),
											child: Row(
												children: [
													Container(
														width: 40, height: 40,
														decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
														child: const Icon(Icons.location_on, color: Colors.orange),
													),
													const SizedBox(width: 16),
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text(goal.locationName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
																if (goal.latitude != null)
																	Text("${goal.latitude!.toStringAsFixed(4)}, ${goal.longitude!.toStringAsFixed(4)}",
																			style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
															],
														),
													)
												],
											),
										),
										const SizedBox(height: 100), // Space for floating bottom bar
									],
								],
							),
						),
					),
				],
			),

			// 7. FLOATING ACTION BAR (Bottom)
			floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
			floatingActionButton: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 24),
				child: _buildBottomAction(goal),
			),
		);
	}

	Widget _buildBottomAction(Goal goal) {
		if (goal.status == GoalStatus.completed) {
			// Completed State: Show "Convert" or "Unmark"
			return Row(
				children: [
					Expanded(
						child: ElevatedButton.icon(
							onPressed: () => _markStatus(GoalStatus.inProgress),
							icon: const Icon(Icons.undo),
							label: const Text("Undo"),
							style: ElevatedButton.styleFrom(
								backgroundColor: Colors.grey.shade700,
								foregroundColor: Colors.white,
								padding: const EdgeInsets.symmetric(vertical: 16),
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
							),
						),
					),
					const SizedBox(width: 12),
					if (!goal.convertedToAchievement)
						Expanded(
							flex: 2,
							child: ElevatedButton.icon(
								onPressed: _markCompletedAsAchievement,
								icon: const Icon(Icons.emoji_events),
								label: const Text("Claim Trophy"),
								style: ElevatedButton.styleFrom(
									backgroundColor: Colors.amber.shade700, // Gold color
									foregroundColor: Colors.white,
									elevation: 4,
									padding: const EdgeInsets.symmetric(vertical: 16),
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
								),
							),
						),
				],
			);
		} else {
			// In Progress State: Show "Mark Complete"
			return SizedBox(
				width: double.infinity,
				child: ElevatedButton.icon(
					onPressed: () => _markStatus(GoalStatus.completed),
					icon: const Icon(Icons.check_circle),
					label: const Text("Mark Goal Complete"),
					style: ElevatedButton.styleFrom(
						backgroundColor: AppColors.primary,
						foregroundColor: Colors.white,
						elevation: 5,
						shadowColor: AppColors.primary.withOpacity(0.4),
						padding: const EdgeInsets.symmetric(vertical: 18),
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
						textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
					),
				),
			);
		}
	}
}