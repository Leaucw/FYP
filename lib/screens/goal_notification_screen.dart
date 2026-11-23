import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal.dart';
import '../models/goal_notification.dart';
import '../services/goal_notification_service.dart'; // Make sure this path is correct
import '../services/goal_service.dart';
import '../theme/app_colors.dart'; // Import your colors
import 'goal_view_screen.dart';

class NotificationScreen extends StatelessWidget {
  final String userId;

  final GoalService _goalService = GoalService(db: FirebaseFirestore.instance);
  final NotificationService _notifService = NotificationService();

  NotificationScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),

      // ---------------------------------------------------------
      // UPDATED APP BAR DESIGN
      // ---------------------------------------------------------
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary, // Match your theme color
        foregroundColor: Colors.white,      // Makes back button white
        centerTitle: true,

        // Title + Icon Row
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),

              child: const Icon(
                  Icons.notifications,
                  color: Colors.white,
                  size: 18
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "Notifications",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),

        // Background Decor (Faint Icon)
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

      // ---------------------------------------------------------
      // BODY (Logic remains the same)
      // ---------------------------------------------------------
      body: StreamBuilder<List<Goal>>(
        stream: _goalService.streamGoals(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final goals = snapshot.data ?? [];
          final notifications = _notifService.getAlertsFromGoals(goals);

          if (notifications.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return _NotificationCard(
                notification: notifications[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoalViewScreen(
                          goalId: notifications[index].goalId,
                          userId: userId
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 20,
                      offset: const Offset(0, 10)
                  )
                ]
            ),
            child: Icon(Icons.check_circle_outline, size: 60, color: Colors.green.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Text(
              "All Caught Up!",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary
              )
          ),
          const SizedBox(height: 8),
          Text(
              "No urgent deadlines right now.",
              style: TextStyle(color: Colors.grey.shade500)
          ),
        ],
      ),
    );
  }
}

// --- Card Component (Slightly polished to match new background) ---
class _NotificationCard extends StatelessWidget {
  final GoalNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMissed = notification.type == NotificationType.missed;
    final color = isMissed ? Colors.redAccent : Colors.orange;
    final bgColor = isMissed ? Colors.red.shade50 : Colors.orange.shade50;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            // Icon Indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                  isMissed ? Icons.warning_amber_rounded : Icons.hourglass_top_rounded,
                  size: 24,
                  color: color
              ),
            ),
            const SizedBox(width: 16),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          notification.title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 15
                          )
                      ),
                      Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300)
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                      notification.message,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4
                      )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}