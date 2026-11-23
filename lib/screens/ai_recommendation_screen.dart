import 'dart:convert';
import 'dart:async'; // Required for TimeoutException
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'article_detail_screen.dart'; // Ensure this file exists
import 'analytics_dashboard_screen.dart';
import 'mbti_analytics_screen.dart';
import 'side_navigation_drawer.dart';

// --- CONSTANTS ---
const Color kPrimaryDeep = Color(0xFF2A2D3E);
const Color kAccentPurple = Color(0xFF6C63FF);

class AiRecommendationScreen extends StatefulWidget {
  const AiRecommendationScreen({super.key});

  @override
  State<AiRecommendationScreen> createState() => _AiRecommendationScreenState();
}

class _AiRecommendationScreenState extends State<AiRecommendationScreen> {
  List<_Article> _articles = [];
  bool _isLoading = true;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = "";
      });
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() { _errorMessage = "Please log in."; _isLoading = false; });
      return;
    }

    try {
      // 1. Get User Goals
      final snapshot = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('goals').get();

      String userContext = "";
      if (snapshot.docs.isNotEmpty) {
        userContext = snapshot.docs
            .map((doc) => "${doc['title']}. ${doc['description'] ?? ''}")
            .join(" ");
      } else {
        userContext = "I want to improve my career and health.";
      }

      // 2. Call Python API (Use 10.0.2.2 for Android Emulator, localhost for iOS)
      final url = Uri.parse('http://10.0.2.2:5000/recommend');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"goal": userContext}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _articles = data.map((json) => _Article.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to connect to AI server. Please check your connection.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      drawer: const SideNavigationDrawer(currentScreen: 'ai'),
      body: CustomScrollView(
        slivers: [
          // 1. Top Bar (Always Visible)
          _buildSliverAppBar(),

          // 2. Loading State (Fills remaining space)
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: kAccentPurple),
              ),
            )

          // 3. Error State (Fills remaining space)
          else if (_errorMessage.isNotEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _fetchRecommendations,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryDeep,
                        foregroundColor: Colors.white,
                      ),
                    )
                  ],
                ),
              ),
            )

          // 4. Success Content
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final article = _articles[index];
                    if (index == 0) return _HeroArticleCard(article: article);
                    return _ArticleListItem(article: article, index: index);
                  },
                  childCount: _articles.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- DRAWER ---
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: kPrimaryDeep),
            child: const Text("Navigation", style: TextStyle(color: Colors.white, fontSize: 22)),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: kPrimaryDeep),
            title: const Text("Dashboard"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AnalyticsDashboardScreen())
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: Colors.amber),
            title: const Text("AI Recommendations"),
            tileColor: Colors.amber.withOpacity(0.1), // Active Highlight
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 8)),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.psychology, color: kAccentPurple),
            title: const Text("MBTI Analytics"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MbtiAnalyticsScreen())
              );
            },
          ),
        ],
      ),
    );
  }

  // --- SLIVER APP BAR ---
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
                border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
              ),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.amber),
            ),
            const SizedBox(width: 8),
            const Text("AI Coach", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: kPrimaryDeep),
            Positioned(
              right: -20, top: -10,
              child: Icon(Icons.auto_awesome_motion, size: 150, color: Colors.white.withOpacity(0.05)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS ---

class _HeroArticleCard extends StatelessWidget {
  final _Article article;
  const _HeroArticleCard({required this.article});

  LinearGradient _getPremiumGradient(String category) {
    final cat = category.toLowerCase();
    if (cat.contains("health")) return const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]);
    if (cat.contains("career") || cat.contains("finance")) return const LinearGradient(colors: [Color(0xFF11998e), Color(0xFF38ef7d)]);
    if (cat.contains("learn") || cat.contains("education")) return const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]);
    if (cat.contains("relation")) return const LinearGradient(colors: [Color(0xFFEC008C), Color(0xFFFC6767)]);
    return const LinearGradient(colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        height: 220,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: _getPremiumGradient(article.category),
                boxShadow: [BoxShadow(color: article.color.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
              ),
            ),
            Positioned(
              right: -20, top: -20,
              child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle)),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 6),
                        Text("TOP MATCH: ${article.matchScore.toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(article.category.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(article.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  const Row(children: [Text("Tap to read", style: TextStyle(color: Colors.white)), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16)]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleListItem extends StatelessWidget {
  final _Article article;
  final int index;
  const _ArticleListItem({required this.article, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article))),
        leading: CircleAvatar(
          backgroundColor: article.color.withOpacity(0.1),
          child: Text("${index + 1}", style: TextStyle(color: article.color, fontWeight: FontWeight.bold)),
        ),
        title: Text(article.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(article.category, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text("${article.matchScore.toInt()}%", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}

// --- DATA MODELS ---

class _Article {
  final String title;
  final String category;
  final String content;
  final double matchScore;
  final Color color;

  _Article({required this.title, required this.category, required this.content, required this.matchScore, required this.color});

  factory _Article.fromJson(Map<String, dynamic> json) {
    Color getColor(String cat) {
      final lower = cat.toLowerCase();
      if (lower.contains("health")) return Colors.orange;
      if (lower.contains("finance") || lower.contains("career")) return Colors.green;
      if (lower.contains("learn") || lower.contains("education")) return Colors.indigo;
      if (lower.contains("relation")) return Colors.pinkAccent;
      return Colors.blueAccent;
    }

    String catName = json['category'] ?? "General";
    return _Article(
      title: json['title'] ?? "No Title",
      category: catName,
      content: json['content'] ?? "",
      matchScore: (json['match_score'] ?? 0).toDouble(),
      color: getColor(catName),
    );
  }
}