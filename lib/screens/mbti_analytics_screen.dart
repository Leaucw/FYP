import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

import 'ai_recommendation_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'side_navigation_drawer.dart';

// Constants matching your DashboardTheme
const Color kPrimaryDeep = Color(0xFF2A2D3E);
const Color kAccentPurple = Color(0xFF6C63FF);
const Color kCardBg = Colors.white;

class MbtiAnalyticsScreen extends StatefulWidget {
  const MbtiAnalyticsScreen({super.key});

  @override
  State<MbtiAnalyticsScreen> createState() => _MbtiAnalyticsScreenState();
}

class _MbtiAnalyticsScreenState extends State<MbtiAnalyticsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // State
  bool _isLoading = true;
  String? _currentUserMbti;
  String _selectedMbti = "ENTJ"; // Default, will update to user's
  String _distributionFilter = "Community"; // Community, Friends, Interacted

  // Data Containers
  Map<String, double> _communityStats = {};
  Map<String, double> _friendsStats = {};
  Map<String, double> _interactionStats = {};
  Map<String, double> _currentFitScores = {};

  // Insight Data
  String _insightText = "Analyze your goals to see insights.";
  String _lowestCategory = "";
  int _goalsInLowest = 0;

  // Static list for dropdown
  final List<String> _mbtiTypes = [
    "INTJ", "INTP", "ENTJ", "ENTP",
    "INFJ", "INFP", "ENFJ", "ENFP",
    "ISTJ", "ISFJ", "ESTJ", "ESFJ",
    "ISTP", "ISFP", "ESTP", "ESFP"
  ];

  final Map<String, String> _quotes = {
    "ENTJ": "Efficiency is doing things right; effectiveness is doing the right things.",
    "INTJ": "Thought constitutes the greatness of man. Man is a reed, the weakest in nature, but he is a thinking reed.",
    "ENFP": "Creativity is intelligence having fun.",
    "ISFJ": "Love and kindness are never wasted.",
    "default": "The only way to do great work is to love what you do."
  };

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Get Current User MBTI
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('mbti')) {
          setState(() {
            _currentUserMbti = data['mbti'];
            _selectedMbti = _currentUserMbti ?? "ENTJ"; // Set default selection
          });
        }
      }

      // 2. Calculate Distributions (Parallel execution for speed)
      await Future.wait([
        _calcCommunityDistribution(),
        _calcFriendsAndInteractionDistribution(user.uid),
      ]);

      // 3. Calculate Fit Score & Insight for the *Selected* MBTI
      await _calculateFitAndInsight(user.uid);

    } catch (e) {
      debugPrint("Error loading analytics: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC 1: Community Distribution (All Users) ---
  Future<void> _calcCommunityDistribution() async {
    // Note: In a real app with 1M users, use an aggregation query or cloud function.
    // Here we query the users collection directly.
    final snap = await _firestore.collection('users').get();
    final total = snap.docs.length;
    if (total == 0) return;

    final counts = <String, int>{};
    for (var doc in snap.docs) {
      final mbti = doc.data()['mbti'] as String? ?? "Unknown";
      if (_mbtiTypes.contains(mbti)) {
        counts[mbti] = (counts[mbti] ?? 0) + 1;
      }
    }

    _communityStats = {};
    counts.forEach((key, count) {
      _communityStats[key] = count / total;
    });
  }

  // --- LOGIC 2 & 3: Friends & Interactions ---
  Future<void> _calcFriendsAndInteractionDistribution(String uid) async {
    // A. Get Relationships (Friends)
    final relSnap = await _firestore.collection('users').doc(uid).collection('relationships').get();

    // Create Map: Name -> MBTI
    final nameToMbti = <String, String>{};
    final friendCounts = <String, int>{};

    for (var doc in relSnap.docs) {
      final data = doc.data();
      final mbti = data['mbti'] as String? ?? "";
      final name = data['name'] as String? ?? "";

      if (name.isNotEmpty && _mbtiTypes.contains(mbti)) {
        nameToMbti[name] = mbti;
        friendCounts[mbti] = (friendCounts[mbti] ?? 0) + 1;
      }
    }

    // Set Friends Stats
    int totalFriends = relSnap.docs.length;
    _friendsStats = {};
    if (totalFriends > 0) {
      friendCounts.forEach((key, count) {
        _friendsStats[key] = count / totalFriends;
      });
    }

    // B. Get Goals (Interactions)
    final goalSnap = await _firestore.collection('users').doc(uid).collection('goals').get();

    final interactionCounts = <String, int>{};
    int totalInteractions = 0;

    for (var doc in goalSnap.docs) {
      final data = doc.data();
      // 'associatedPeople' is likely a List<dynamic>
      final people = List<String>.from(data['associatedPeople'] ?? []);

      for (var personName in people) {
        // Find this person's MBTI from our relationship map
        final mbti = nameToMbti[personName];
        if (mbti != null) {
          interactionCounts[mbti] = (interactionCounts[mbti] ?? 0) + 1;
          totalInteractions++;
        }
      }
    }

    // Set Interaction Stats
    _interactionStats = {};
    if (totalInteractions > 0) {
      interactionCounts.forEach((key, count) {
        _interactionStats[key] = count / totalInteractions;
      });
    }
  }

  // --- LOGIC 4 & 5: Fit Score & Insight ---
  Future<void> _calculateFitAndInsight(String uid) async {
    // In a real app, "All User Data" for fit scores requires backend aggregation.
    // Here, we calculate the fit based on the CURRENT USER's performance
    // and normalize it.

    final goalSnap = await _firestore.collection('users').doc(uid).collection('goals').get();
    final docs = goalSnap.docs;

    Map<String, int> totalByCategory = {};
    Map<String, int> completedByCategory = {};

    for (var doc in docs) {
      final data = doc.data();
      final cat = data['category'] ?? "General";
      final status = data['status']; // Assuming 'completed' is a status string or enum index

      totalByCategory[cat] = (totalByCategory[cat] ?? 0) + 1;

      // Check if completed (Adjust logic based on your Goal model)
      // Assuming GoalStatus.completed is stored as string 'completed' or int 1
      if (status == 'completed' || status == 1 || data['completedAt'] != null) {
        completedByCategory[cat] = (completedByCategory[cat] ?? 0) + 1;
      }
    }

    // Calculate Raw Scores (Completion Rate)
    Map<String, double> rawScores = {};
    totalByCategory.forEach((cat, total) {
      int completed = completedByCategory[cat] ?? 0;
      rawScores[cat] = total == 0 ? 0.0 : (completed / total);
    });

    // If viewing Current User's MBTI, show their real stats.
    // If viewing others, we simulate "Community Data" by randomizing slightly
    // around the user's data (since we can't read other users' goals securely).
    if (_selectedMbti == _currentUserMbti) {
      _currentFitScores = rawScores;
    } else {
      // Simulation for demo purposes of "Community Average for ENTJ" etc.
      final random = Random(_selectedMbti.hashCode);
      _currentFitScores = {};
      const categories = ['Health & Wellness', 'Career & Finance', 'Education & Learning', 'Relationships', 'Personal Growth'];
      for (var cat in categories) {
        _currentFitScores[cat] = (random.nextDouble() * 0.5) + 0.4; // Random between 0.4 and 0.9
      }
    }

    // Generate Insight (Lowest Category)
    if (_currentFitScores.isNotEmpty) {
      var sortedEntries = _currentFitScores.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      _lowestCategory = sortedEntries.first.key;
      _goalsInLowest = completedByCategory[_lowestCategory] ?? 0;

      _insightText = "This month you completed $_goalsInLowest goals in your lowest-fit category: $_lowestCategory. Excellent effort in developing your weak zone!";
    } else {
      _insightText = "Complete more goals to unlock personality insights.";
    }

    // Ensure we trigger rebuild if called from dropdown change
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      drawer: const SideNavigationDrawer(currentScreen: 'mbti'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          _buildSliverAppBar(),

          // 1. Selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: _buildMbtiSelector(),
            ),
          ),

          // 2. Daily Quote
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: _buildDailyQuoteCard(),
            ),
          ),


          // 4. Distribution
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              child: _buildDistributionCard(),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: DashboardTheme.primaryDeep),
            child: const Text(
              "Navigation",
              style: TextStyle(color: Colors.white, fontSize: 22),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: DashboardTheme.primaryDeep),
            title: const Text("Dashboard"),

            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AnalyticsDashboardScreen())
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.amber),
            title: const Text("AI Recommendations"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 8)),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AiRecommendationScreen())
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology, color: DashboardTheme.accentPurple),
            title: const Text("MBTI Analytics"),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 100.0,
      pinned: true,
      floating: false,
      backgroundColor: kPrimaryDeep,
      foregroundColor: Colors.white,
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
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        expandedTitleScale: 1.0,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kPrimaryDeep,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.psychology, size: 18, color: kAccentPurple),
            ),
            const SizedBox(width: 8),
            const Text("MBTI Analytics", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: kPrimaryDeep),
            Positioned(
              right: -20, top: -10,
              child: Icon(Icons.analytics, size: 150, color: Colors.white.withOpacity(0.05)),
            ),
          ],
        ),
      ),
    );
  }

  // --- SELECTOR ---
  Widget _buildMbtiSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Analyzing For", style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMbti,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: kAccentPurple),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryDeep),
                  items: _mbtiTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedMbti = v!);
                    // Recalculate stats when selection changes
                    _calculateFitAndInsight(_auth.currentUser!.uid);
                  },
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _getMbtiColor(_selectedMbti).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.fingerprint, color: _getMbtiColor(_selectedMbti)),
          )
        ],
      ),
    );
  }

  // --- DAILY QUOTE ---
  Widget _buildDailyQuoteCard() {
    final quote = _quotes[_selectedMbti] ?? _quotes["default"]!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kAccentPurple, kAccentPurple.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: kAccentPurple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded, color: Colors.white70),
              const SizedBox(width: 8),
              Text("$_selectedMbti Daily Insight", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "\"$quote\"",
            style: const TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic, height: 1.4),
          ),
        ],
      ),
    );
  }



  Widget _buildFitBar(String label, double score) {
    Color barColor = score < 0.4 ? Colors.redAccent : (score < 0.7 ? Colors.orangeAccent : Colors.green);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2A2D3E))),
              Text("${(score * 100).toInt()}% fit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: barColor)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }

  // --- DISTRIBUTION ---
  Widget _buildDistributionCard() {
    // Select the correct map based on filter
    Map<String, double> data;
    if (_distributionFilter == "Community") data = _communityStats;
    else if (_distributionFilter == "Friends") data = _friendsStats;
    else data = _interactionStats;

    // Sort data high to low
    var sortedKeys = data.keys.toList(growable: false)
      ..sort((k1, k2) => data[k2]!.compareTo(data[k1]!));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Type Distribution", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryDeep)),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _distributionFilter,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kAccentPurple),
                  icon: const Icon(Icons.arrow_drop_down, color: kAccentPurple),
                  items: ["Community", "Friends", "Interacted"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _distributionFilter = v!),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),

          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("No data available for this filter."),
            )
          else
            ...sortedKeys.take(8).map((key) => _buildDistributionRow(key, data[key]!)),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String mbti, double percent) {
    final color = _getMbtiColor(mbti);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 45,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(mbti, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              children: [
                Container(height: 10, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(5))),
                FractionallySizedBox(
                  widthFactor: percent,
                  child: Container(height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text("${(percent * 100).toInt()}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Color _getMbtiColor(String mbti) {
    if (['INTJ', 'INTP', 'ENTJ', 'ENTP'].contains(mbti)) return const Color(0xFF8869AD);
    if (['INFJ', 'INFP', 'ENFJ', 'ENFP'].contains(mbti)) return const Color(0xFF32A474);
    if (['ISTJ', 'ISFJ', 'ESTJ', 'ESFJ'].contains(mbti)) return const Color(0xFF4298B4);
    if (['ISTP', 'ISFP', 'ESTP', 'ESFP'].contains(mbti)) return const Color(0xFFE4AE3A);
    return Colors.grey;
  }
}