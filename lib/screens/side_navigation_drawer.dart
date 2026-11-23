import 'package:flutter/material.dart';
import 'analytics_dashboard_screen.dart'; // Import your screens
import 'ai_recommendation_screen.dart';
import 'mbti_analytics_screen.dart';

// Constants matching your theme
const Color kPrimaryDeep = Color(0xFF2A2D3E);
const Color kAccentPurple = Color(0xFF6C63FF);

class SideNavigationDrawer extends StatelessWidget {
  final String currentScreen; // 'dashboard', 'ai', 'mbti'

  const SideNavigationDrawer({super.key, required this.currentScreen});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. Header
          DrawerHeader(
            decoration: const BoxDecoration(color: kPrimaryDeep),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 10),
                const Text(
                  "Navigation",
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // 2. Dashboard Link
          _buildDrawerItem(
            context,
            icon: Icons.dashboard,
            label: "Dashboard",
            isSelected: currentScreen == 'dashboard',
            color: kPrimaryDeep,
            onTap: () {
              if (currentScreen != 'dashboard') {
                Navigator.pop(context); // Close drawer
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AnalyticsDashboardScreen()),
                );
              } else {
                Navigator.pop(context); // Just close drawer if already here
              }
            },
          ),

          // 3. AI Coach Link
          _buildDrawerItem(
            context,
            icon: Icons.auto_awesome,
            label: "AI Recommendations",
            isSelected: currentScreen == 'ai',
            color: Colors.amber,
            isNew: true,
            onTap: () {
              if (currentScreen != 'ai') {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AiRecommendationScreen()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),

          // 4. MBTI Link
          _buildDrawerItem(
            context,
            icon: Icons.psychology,
            label: "MBTI Analytics",
            isSelected: currentScreen == 'mbti',
            color: kAccentPurple,
            onTap: () {
              if (currentScreen != 'mbti') {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MbtiAnalyticsScreen()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  // Helper Widget for consistent styling
  Widget _buildDrawerItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required bool isSelected,
        required Color color,
        required VoidCallback onTap,
        bool isNew = false,
      }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? color : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? color : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? color.withOpacity(0.1) : null,
      trailing: isNew
          ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
        child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 8)),
      )
          : null,
      onTap: onTap,
    );
  }
}