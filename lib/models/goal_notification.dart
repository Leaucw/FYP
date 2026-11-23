import '../models/goal.dart';

enum NotificationType { urgent, missed }

class GoalNotification {
  final String id;
  final String goalId;
  final String title;
  final String message;
  final NotificationType type;

  GoalNotification({
    required this.id,
    required this.goalId,
    required this.title,
    required this.message,
    required this.type,
  });

  // --- LOGIC: Converts a Goal into a Notification if necessary ---
  static GoalNotification? fromGoal(Goal goal) {
    // 1. If goal is done or has no deadline, no notification needed.
    if (goal.endDate == null || goal.status == GoalStatus.completed) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(goal.endDate!.year, goal.endDate!.month, goal.endDate!.day);

    final diff = due.difference(today).inDays;

    // 2. Check for Missed (Negative difference)
    if (diff < 0) {
      return GoalNotification(
        id: "notif_missed_${goal.id}",
        goalId: goal.id,
        title: "Goal Missed!",
        message: "The deadline for '${goal.title}' has passed.",
        type: NotificationType.missed,
      );
    }
    // 3. Check for Urgent (Due today (0) or tomorrow (1))
    else if (diff <= 1) {
      return GoalNotification(
        id: "notif_urgent_${goal.id}",
        goalId: goal.id,
        title: diff == 0 ? "Due Today!" : "Due Tomorrow!",
        message: "'${goal.title}' is ending soon. Finish strong!",
        type: NotificationType.urgent,
      );
    }

    return null; // Not urgent yet
  }
}