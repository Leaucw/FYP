import '../models/goal.dart';
import '../models/goal_notification.dart';

class NotificationService {

  // Takes a list of raw goals and returns a sorted list of alerts
  List<GoalNotification> getAlertsFromGoals(List<Goal> goals) {

    // 1. Convert Goals to Notifications
    final alerts = goals
        .map((g) => GoalNotification.fromGoal(g)) // Use the logic in the Model
        .whereType<GoalNotification>()            // Remove nulls
        .toList();

    // 2. Sort: Missed (Red) goes to the top, then Urgent (Orange)
    alerts.sort((a, b) {
      if (a.type == b.type) return 0;
      return a.type == NotificationType.missed ? -1 : 1;
    });

    return alerts;
  }
}