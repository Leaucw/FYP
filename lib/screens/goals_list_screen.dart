import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/goal.dart';
import '../models/goal_notification.dart';
import '../services/goal_service.dart';
import '../theme/app_colors.dart';
import 'goal_notification_screen.dart';
import 'goal_upsert_screen.dart';
import 'goal_view_screen.dart';

class GoalsListScreen extends StatefulWidget {
	const GoalsListScreen({super.key});

	@override
	State<GoalsListScreen> createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends State<GoalsListScreen> {
	final _auth = FirebaseAuth.instance;
	final _service = GoalService(db: FirebaseFirestore.instance);

	GoalStatus? selectedFilter; // null = ALL

	@override
	Widget build(BuildContext context) {
		final user = _auth.currentUser;

		if (user == null) {
			return const Scaffold(
				body: Center(child: Text("Please sign in to view goals")),
			);
		}

		return Scaffold(
			// Use the off-white background for contrast with white cards
			backgroundColor: const Color(0xFFF8F9FC),
				appBar: AppBar(
					elevation: 0,
					backgroundColor: AppColors.primary,       // SAME COLOR
					foregroundColor: Colors.white,
					centerTitle: true,                        // SAME CENTERED STYLE

					// Title + Icon (matching Life Timeline)
					title: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Icon(
								Icons.flag_rounded,                 // TITLE ICON
								color: Colors.white,
								size: 22,
							),
							const SizedBox(width: 8),
							const Text(
								"My Goals",
								style: TextStyle(
									fontSize: 20,                     // SAME FONT SIZE
									fontWeight: FontWeight.w600,      // SAME FONT WEIGHT
									color: Colors.white,
								),
							),
						],
					),

					// Right-side action button
					actions: [
						// NOTIFICATION BUTTON WITH BADGE
						StreamBuilder<List<Goal>>(
								stream: _service.streamGoals(user.uid),
								builder: (context, snapshot) {
									final goals = snapshot.data ?? [];
									// Calculate count of urgent/missed items
									final notificationCount = goals.where((g) {
										final notif = GoalNotification.fromGoal(g);
										return notif != null;
									}).length;

									return Container(
										margin: const EdgeInsets.only(right: 12),

										child: Stack(
											alignment: Alignment.center,
											children: [
												IconButton(
													icon: const Icon(Icons.notifications_outlined, color: Colors.white),
													onPressed: () {
														Navigator.push(
															context,
															MaterialPageRoute(
																builder: (_) => NotificationScreen(userId: user.uid),
															),
														);
													},
												),
												// RED DOT BADGE
												if (notificationCount > 0)
													Positioned(
														top: 8,
														right: 8,
														child: Container(
															width: 10,
															height: 10,
															decoration: BoxDecoration(
																color: Colors.redAccent,
																shape: BoxShape.circle,
																border: Border.all(color: AppColors.primary, width: 1.5),
															),
														),
													),
											],
										),
									);
								}
						),
						Container(
							margin: const EdgeInsets.only(right: 16),
							decoration: BoxDecoration(
								color: Colors.white,
								shape: BoxShape.circle,
								boxShadow: [
									BoxShadow(
										color: Colors.black.withOpacity(0.1),
										blurRadius: 12,
									),
								],
							),

						),
					],

					// Background Icon (same style as Life Timeline)
					flexibleSpace: Stack(
						children: [
							Positioned(
								right: -20,
								bottom: -20,
								child: Icon(
									Icons.analytics,        // BACKGROUND DECOR ICON
									size: 150,
									color: Colors.white.withOpacity(0.05),
								),
							),
						],
					),
				),


				body: Column(
				children: [
					// -------------------------------------------------------
					// FILTER BAR
					// -------------------------------------------------------
					Padding(
						padding: const EdgeInsets.symmetric(vertical: 12),
						child: _buildFilterBar(),
					),

					// -------------------------------------------------------
					// GOALS LIST STREAM
					// -------------------------------------------------------
					Expanded(
						child: StreamBuilder<List<Goal>>(
							stream: _service.streamGoals(user.uid),
							builder: (context, snapshot) {
								if (snapshot.connectionState == ConnectionState.waiting) {
									return const Center(child: CircularProgressIndicator());
								}

								var goals = snapshot.data ?? [];

								// Filter Logic
								if (selectedFilter != null) {
									goals = goals.where((g) => g.status == selectedFilter).toList();
								}

								// Sort by Urgency (Overdue first, then by end date)
								goals.sort((a, b) {
									if (a.endDate == null) return 1;
									if (b.endDate == null) return -1;
									return a.endDate!.compareTo(b.endDate!);
								});

								if (goals.isEmpty) return _buildEmptyState();

								return ListView.builder(
									padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
									itemCount: goals.length,
									itemBuilder: (_, i) {
										return _GoalCard(
											goal: goals[i],
											userId: user.uid,
											onTap: () {
												Navigator.push(
													context,
													MaterialPageRoute(
														builder: (_) => GoalViewScreen(goalId: goals[i].id, userId: user.uid),
													),
												);
											},
											onEdit: () {
												Navigator.push(
													context,
													MaterialPageRoute(
														builder: (_) => GoalUpsertScreen.edit(existing: goals[i]),
													),
												);
											},
										);
									},
								);
							},
						),
					),
				],
			),

			floatingActionButton: FloatingActionButton.extended(
				backgroundColor: AppColors.primary,
				elevation: 4,
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
				onPressed: () {
					Navigator.push(
						context,
						MaterialPageRoute(builder: (_) => const GoalUpsertScreen.create()),
					);
				},
				icon: const Icon(Icons.add, color: Colors.white),
				label: const Text("New Goal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
			),
		);
	}

	Widget _buildEmptyState() {
		return Center(
			child: Column(
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					Icon(Icons.rocket_launch_outlined, size: 80, color: Colors.grey.shade300),
					const SizedBox(height: 16),
					Text(
						"No goals found",
						style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
					),
					Text(
						"Time to start your journey!",
						style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
					),
				],
			),
		);
	}

	Widget _buildFilterBar() {
		final items = {
			null: "All Goals",
			GoalStatus.inProgress: "In Progress",
			GoalStatus.completed: "Completed",
			GoalStatus.missed: "Missed"
		};

		return SingleChildScrollView(
			scrollDirection: Axis.horizontal,
			padding: const EdgeInsets.symmetric(horizontal: 20),
			physics: const BouncingScrollPhysics(),
			child: Row(
				children: items.entries.map((entry) {
					final isSelected = selectedFilter == entry.key;
					return Padding(
						padding: const EdgeInsets.only(right: 10),
						child: AnimatedContainer(
							duration: const Duration(milliseconds: 200),
							child: FilterChip(
								label: Text(entry.value),
								selected: isSelected,
								showCheckmark: false,
								backgroundColor: Colors.white,
								selectedColor: AppColors.primary,
								elevation: isSelected ? 4 : 0,
								padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(20),
									side: BorderSide(
										color: isSelected ? Colors.transparent : Colors.grey.shade300,
									),
								),
								labelStyle: TextStyle(
									color: isSelected ? Colors.white : Colors.grey.shade600,
									fontWeight: FontWeight.w600,
								),
								onSelected: (_) {
									setState(() => selectedFilter = entry.key);
								},
							),
						),
					);
				}).toList(),
			),
		);
	}
}

// ---------------------------------------------------------------
// MODERN CARD WIDGET
// ---------------------------------------------------------------

class _GoalCard extends StatelessWidget {
	final Goal goal;
	final String userId;
	final VoidCallback onTap;
	final VoidCallback onEdit;

	const _GoalCard({
		required this.goal,
		required this.userId,
		required this.onTap,
		required this.onEdit,
	});

	// Helper for Category Colors (Pastels)
	Color _getCategoryColor(String cat) {
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
			case "Health & Wellness": return Colors.green.shade700;
			case "Career & Finance": return Colors.blue.shade700;
			case "Education & Learning": return Colors.orange.shade700;
			case "Relationships": return Colors.pink.shade700;
			default: return Colors.purple.shade700;
		}
	}

	IconData _iconForCategory(String cat) {
		switch (cat) {
			case "Health & Wellness": return Icons.spa_outlined;
			case "Career & Finance": return Icons.account_balance_wallet_outlined;
			case "Education & Learning": return Icons.school_outlined;
			case "Relationships": return Icons.favorite_border;
			default: return Icons.star_outline;
		}
	}

	@override
	Widget build(BuildContext context) {
		final completed = goal.subGoals.where((s) => s.completed).length;
		final total = goal.subGoals.length;
		final progress = total == 0 ? 0.0 : completed / total;

		final accentColor = _getCategoryAccent(goal.category);
		final bgColor = _getCategoryColor(goal.category);

		// Deadline Logic
		Color dateColor = Colors.grey.shade500;
		String dateText = goal.endDate != null ? DateFormat('MMM d').format(goal.endDate!) : "No Deadline";

		if (goal.endDate != null && goal.status != GoalStatus.completed) {
			final diff = goal.endDate!.difference(DateTime.now()).inDays;
			if (diff < 0) {
				dateColor = Colors.red;
				dateText = "Overdue!";
			} else if (diff <= 3) {
				dateColor = Colors.orange;
				dateText = "Due in ${diff}d";
			}
		}

		return GestureDetector(
			onTap: onTap,
			child: Container(
				margin: const EdgeInsets.only(bottom: 16),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(24),
					boxShadow: [
						BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
					],
				),
				child: Column(
					children: [
						Padding(
							padding: const EdgeInsets.all(20),
							child: Row(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									// 1. Category Icon
									Container(
										padding: const EdgeInsets.all(12),
										decoration: BoxDecoration(
											color: bgColor,
											borderRadius: BorderRadius.circular(16),
										),
										child: Icon(_iconForCategory(goal.category), color: accentColor, size: 22),
									),

									const SizedBox(width: 16),

									// 2. Main Content
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Row(
													mainAxisAlignment: MainAxisAlignment.spaceBetween,
													children: [
														Flexible(
															child: Text(
																goal.title,
																style: const TextStyle(
																	fontSize: 17,
																	fontWeight: FontWeight.bold,
																	color: Colors.black87,
																	height: 1.2,
																),
																maxLines: 2,
																overflow: TextOverflow.ellipsis,
															),
														),
														if (goal.status == GoalStatus.completed)
															const Icon(Icons.check_circle, color: Colors.green, size: 20),
													],
												),
												const SizedBox(height: 6),
												if (goal.description.isNotEmpty)
													Text(
														goal.description,
														maxLines: 1,
														overflow: TextOverflow.ellipsis,
														style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
													),
											],
										),
									),
								],
							),
						),

						// 3. Divider
						Divider(height: 1, color: Colors.grey.shade100),

						// 4. Footer (Progress & Metadata)
						Container(
							padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
							decoration: BoxDecoration(
								color: Colors.grey.shade50.withOpacity(0.5),
								borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
							),
							child: Row(
								children: [
									// Progress Bar
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Row(
													children: [
														Expanded(
															child: ClipRRect(
																borderRadius: BorderRadius.circular(4),
																child: LinearProgressIndicator(
																	value: progress,
																	minHeight: 6,
																	backgroundColor: Colors.grey.shade200,
																	valueColor: AlwaysStoppedAnimation(
																			goal.status == GoalStatus.completed ? Colors.green : accentColor
																	),
																),
															),
														),
														const SizedBox(width: 10),
														Text(
															"${(progress * 100).toInt()}%",
															style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
														),
													],
												),
											],
										),
									),

									const SizedBox(width: 16),

									// Date & Edit
									Row(
										children: [
											Icon(Icons.calendar_today_rounded, size: 14, color: dateColor),
											const SizedBox(width: 4),
											Text(
												dateText,
												style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dateColor),
											),
											const SizedBox(width: 12),
											GestureDetector(
												onTap: onEdit,
												child: Icon(Icons.edit, size: 18, color: Colors.grey.shade400),
											),
										],
									)
								],
							),
						),
					],
				),
			),
		);
	}
}