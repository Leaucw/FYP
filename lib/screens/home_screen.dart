import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:fyp/screens/social_hub_screen.dart';
import '../theme/app_colors.dart';
import 'achievements_list_screen.dart';
import 'profile_screen.dart';
import 'goals_list_screen.dart';
import 'timeline_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'life_map_screen.dart';
import 'connections_screen.dart';
import 'journal_list_screen.dart';

// ⭐ NEW IMPORT
import 'connections_screen.dart';
import 'journal_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _selectedIndex = 0;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user!.uid).get();
      if (doc.exists) _userData = doc.data();
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _userData?['name'] ?? user?.displayName ?? "Explorer";
    final points = _userData?['points'] ?? 0;
    final photoBase64 = _userData?['photoBase64'];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA), // Soft grey-blue background
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. ORIGINAL SLIVER APP BAR
            _buildSliverAppBar(name, photoBase64, points),

            // 2. Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
                child: Text(
                  "Your Life Journey",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2D3142),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // 3. BEAUTIFUL BENTO GRID
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: _buildBentoGrid(),
            ),

            // Spacing
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),

      // --- FAB REMOVED HERE ---

      // ORIGINAL BOTTOM NAV BAR
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- WIDGETS ---

  // Inside _HomeScreenState...

  Widget _buildSliverAppBar(String name, String? photo, int points) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.primary,

      automaticallyImplyLeading: false,

      // --- CHANGE START: Added Title ---
      centerTitle: true,
      title: const Text(
        "Home",
        style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18
        ),
      ),
      // --- CHANGE END ---

      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, const Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            // Adjusted padding to avoid overlapping with the "Home" title
            padding: const EdgeInsets.only(left: 20, right: 20, top: 80),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white24,
                    backgroundImage: (photo != null && photo.isNotEmpty)
                        ? MemoryImage(base64Decode(photo))
                        : const AssetImage('assets/images/default_user.png') as ImageProvider,
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Welcome back,", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20)
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text("$points pts", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBentoGrid() {
    final features = [
      _FeatureData("Goals", Icons.track_changes, const Color(0xFFFF9F1C), "Future Plan", () => GoalsListScreen(), isLarge: true),
      _FeatureData("Journal", Icons.book_rounded, const Color(0xFF2EC4B6), "Reflections", () => const JournalListScreen(), isLarge: false),
      _FeatureData("Timeline", Icons.history, const Color(0xFFE71D36), "Life Story", () => TimelineScreen(), isLarge: false),
      _FeatureData("Stats", Icons.pie_chart_rounded, const Color(0xFF7209B7), "Insights", () => AnalyticsDashboardScreen(), isLarge: false),
      _FeatureData("Network", Icons.people_alt_rounded, const Color(0xFF3A86FF), "People", () => ConnectionsScreen(), isLarge: true),
      _FeatureData("Achievements", Icons.emoji_events_rounded, const Color(0xFFFFC300), "Awards", () => AchievementsListScreen(), isLarge: false),
      _FeatureData("Map", Icons.map_rounded, const Color(0xFF38B000), "Travels", () => LifeMapScreen(), isLarge: false),
    ];

    return SliverMasonryGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childCount: features.length,
      itemBuilder: (context, index) {
        return _buildFeatureTile(features[index]);
      },
    );
  }

  Widget _buildFeatureTile(_FeatureData data) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => data.target())),
      child: Container(
        height: data.isLarge ? 180 : 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Decorative Background Icon
            Positioned(
              right: -15,
              bottom: -15,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  data.icon,
                  size: 90,
                  color: data.color.withOpacity(0.08),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: data.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(data.icon, color: data.color, size: 24),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.desc,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          if (i == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: user!)));
          if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SocialHubScreen()),
            );
          }
        },
        elevation: 0,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: "Social"),
        ],
      ),
    );
  }
}

class _FeatureData {
  final String title;
  final IconData icon;
  final Color color;
  final String desc;
  final Widget Function() target;
  final bool isLarge;

  _FeatureData(this.title, this.icon, this.color, this.desc, this.target, {this.isLarge = false});
}