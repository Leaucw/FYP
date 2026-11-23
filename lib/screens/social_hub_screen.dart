import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../theme/app_colors.dart';
import 'edit_post_screen.dart';
import 'comment_screen.dart';
import 'goal_upsert_screen.dart';
import 'profile_screen.dart';

class SocialHubScreen extends StatefulWidget {
  const SocialHubScreen({super.key});

  @override
  State<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends State<SocialHubScreen> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  final int _selectedIndex = 2; // Index 2 is "Social"

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _userData = doc.data();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onBottomNavTap(int index) {
    if (index == 0) {
      Navigator.pop(context); // Go back to Home
    } else if (index == 1) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(user: user!))
      );
    }
  }

  ImageProvider _getUserAvatar() {
    final photoBase64 = _userData?['photoBase64'];
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(photoBase64));
      } catch (e) {
        // Fallback if base64 is corrupt
      }
    }
    // Fallback to asset if no base64
    return const AssetImage('assets/images/default_user.png');
  }

  @override
  Widget build(BuildContext context) {
    final name = _userData?['name'] ?? user?.displayName ?? "Community Member";
    final points = _userData?['points'] ?? 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5FA),

        // --- 1. SLIVER APP BAR & TABS ---
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                floating: false,
                backgroundColor: AppColors.primary,
                automaticallyImplyLeading: false,
                centerTitle: true,
                title: const Text(
                  "Community Hub",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18
                  ),
                ),
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
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 80),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              backgroundImage: _getUserAvatar(),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 10),
                                Text("Welcome back,", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                                Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20)
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text("$points pts", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  tabs: [
                    Tab(text: "Explore"),
                    Tab(text: "My Posts"),
                  ],
                ),
              ),
            ];
          },
          body: const TabBarView(
            children: [
              _FeedList(filter: PostVisibility.all),
              _FeedList(filter: PostVisibility.private),
            ],
          ),
        ),

        // --- 2. BOTTOM NAVIGATION BAR ---
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, -5))
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onBottomNavTap,
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
        ),
      ),
    );
  }
}

class _FeedList extends StatelessWidget {
  final PostVisibility filter;
  const _FeedList({required this.filter});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<Post>>(
      stream: PostService().getFeed(filter, userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong", style: TextStyle(color: Colors.grey[400])));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState();

        final posts = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
          itemCount: posts.length,
          separatorBuilder: (c, i) => const SizedBox(height: 20),
          itemBuilder: (context, index) => _PostCard(post: posts[index], currentUserId: userId),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
              filter == PostVisibility.private ? "Your journey starts here.\nCreate your first goal!" : "It's quiet here.\nBe the first to post!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16, height: 1.5)
          ),
        ],
      ),
    );
  }
}

// --- UPDATED POST CARD: Fetches Author Data Dynamically ---
class _PostCard extends StatelessWidget {
  final Post post;
  final String currentUserId;
  const _PostCard({required this.post, required this.currentUserId});

  /// 1. Fetch the user document based on post.creatorId
  Future<Map<String, dynamic>?> _fetchAuthorData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(post.creatorId)
          .get();
      return doc.data();
    } catch (e) {
      debugPrint("Error fetching author data: $e");
      return null;
    }
  }

  /// 2. Helper to get image provider
  ImageProvider? _getAvatarImage(String? photoString) {
    if (photoString == null || photoString.isEmpty) return null;
    if (photoString.startsWith('http')) {
      return NetworkImage(photoString);
    }
    try {
      return MemoryImage(base64Decode(photoString));
    } catch (e) {
      return null;
    }
  }

  void _showEditDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostScreen(post: post),
        fullscreenDialog: true,
      ),
    );
  }

  // --- Theme Helpers ---
  Color _getCategoryColor(String? category) {
    switch (category) {
      case "Health & Wellness": return Colors.green.shade50;
      case "Career & Finance": return Colors.blue.shade50;
      case "Education & Learning": return Colors.orange.shade50;
      case "Relationships": return Colors.pink.shade50;
      default: return Colors.purple.shade50;
    }
  }

  Color _getAccentColor(String? category) {
    switch (category) {
      case "Health & Wellness": return Colors.green.shade700;
      case "Career & Finance": return Colors.blue.shade700;
      case "Education & Learning": return Colors.orange.shade800;
      case "Relationships": return Colors.pink.shade700;
      default: return Colors.purple.shade700;
    }
  }

  void _adoptGoal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GoalUpsertScreen.adopt(adoptData: post.refData)),
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsBottomSheet(postId: post.id),
    );
  }

  void _handleMenuAction(BuildContext context, String value) {
    if (value == 'edit') {
      _showEditDialog(context);
    } else if (value == 'delete') {
      _confirmDelete(context);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              PostService().deletePost(post.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = post.likes.contains(currentUserId);
    final isOwner = post.creatorId == currentUserId;

    // Theme Colors
    final category = post.refData['category'];
    final bgCol = _getCategoryColor(category);
    final accentCol = _getAccentColor(category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER (Now fetched dynamically)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _fetchAuthorData(),
              builder: (context, snapshot) {
                // Default values from the Post object (in case fetch is slow or fails)
                String displayCreatorName = post.creatorName;
                ImageProvider? displayAvatar = _getAvatarImage(post.creatorPhoto);

                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!;
                  // If we found the user data, use the updated values
                  if (data['name'] != null) displayCreatorName = data['name'];
                  if (data['photoBase64'] != null) {
                    displayAvatar = _getAvatarImage(data['photoBase64']);
                  } else {
                    // If no custom photo, fallback to null (or default)
                    displayAvatar = null;
                  }
                }

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade100,
                      backgroundImage: displayAvatar,
                      child: displayAvatar == null
                          ? Text(
                          displayCreatorName.isNotEmpty ? displayCreatorName[0].toUpperCase() : "?",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)
                      )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayCreatorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(DateFormat.yMMMd().format(post.createdAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                    // EDIT/DELETE MENU
                    if (isOwner)
                      PopupMenuButton<String>(
                        onSelected: (val) => _handleMenuAction(context, val),
                        icon: Icon(Icons.more_horiz, color: Colors.grey.shade400),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),

          // 2. TEXT CONTENT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.content, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: post.tags.map((t) => Text("#$t", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13))).toList(),
                  ),
                ]
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. THE "GOAL TICKET"
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentCol.withOpacity(0.1), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                          category?.toUpperCase() ?? "GOAL",
                          style: TextStyle(color: accentCol, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.flag_rounded, color: accentCol, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.refData['title'] ?? "Untitled Goal",
                  style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                    "${(post.refData['subGoals'] as List).length} Milestones defined",
                    style: TextStyle(color: Colors.black54, fontSize: 13)
                ),
                const SizedBox(height: 16),

                // Adopt Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _adoptGoal(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accentCol,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: accentCol.withOpacity(0.2))),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded, size: 16),
                        SizedBox(width: 8),
                        Text("Adopt this Goal", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),

          // 4. FOOTER
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey(isLiked),
                        color: isLiked ? const Color(0xFFFF5252) : Colors.grey.shade400
                    ),
                  ),
                  onPressed: () => PostService().toggleLike(post.id, currentUserId),
                ),
                Text("${post.likes.length}", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey.shade400),
                  onPressed: () => _showComments(context),
                ),
                Text("${post.commentCount}", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
    );
  }
}