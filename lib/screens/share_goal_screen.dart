import 'dart:convert'; // Required for Base64 decoding
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../theme/app_colors.dart';

class ShareGoalScreen extends StatefulWidget {
  final Goal goal;
  const ShareGoalScreen({super.key, required this.goal});

  @override
  State<ShareGoalScreen> createState() => _ShareGoalScreenState();
}

class _ShareGoalScreenState extends State<ShareGoalScreen> {
  final _contentCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<String> _tags = [];

  // Default to Public
  PostVisibility _visibility = PostVisibility.all;
  bool _isPosting = false;

  // Stores the fetched user details
  String? _userPhotoBase64;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  /// Fetches custom name and avatar from Firestore to ensure consistency
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          setState(() {
            _userPhotoBase64 = doc.data()?['photoBase64'];
            _userName = doc.data()?['name'];
          });
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
      }
    }
  }

  // --- LOGIC ---

  void _addTag() {
    final t = _tagCtrl.text.trim().replaceAll('#', '');
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _tagCtrl.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please write something about your goal."))
      );
      return;
    }
    setState(() => _isPosting = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final goalSnapshot = {
      'title': widget.goal.title,
      'description': widget.goal.description,
      'category': widget.goal.category,
      'subGoals': widget.goal.subGoals.map((s) => s.toMap()).toList(),
    };

    final post = Post(
      id: const Uuid().v4(),
      creatorId: user.uid,
      // Use fetched name if available, else Auth display name, else Fallback
      creatorName: _userName ?? user.displayName ?? "Goal Getter",
      // Use fetched base64 if available, else Auth photo URL
      creatorPhoto: _userPhotoBase64 ?? user.photoURL,
      content: _contentCtrl.text.trim(),
      tags: _tags,
      visibility: _visibility,
      type: PostType.goal,
      createdAt: DateTime.now(),
      refId: widget.goal.id,
      refData: goalSnapshot,
    );

    try {
      await PostService().createPost(post);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Shared successfully!"))
        );
      }
    } catch (e) {
      setState(() => _isPosting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error sharing post: $e"))
        );
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Health & Wellness": return Colors.green.shade50;
      case "Career & Finance": return Colors.blue.shade50;
      case "Education & Learning": return Colors.orange.shade50;
      case "Relationships": return Colors.pink.shade50;
      default: return Colors.purple.shade50;
    }
  }

  Color _getAccentColor(String category) {
    switch (category) {
      case "Health & Wellness": return Colors.green.shade700;
      case "Career & Finance": return Colors.blue.shade700;
      case "Education & Learning": return Colors.orange.shade800;
      case "Relationships": return Colors.pink.shade700;
      default: return Colors.purple.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgCol = _getCategoryColor(widget.goal.category);
    final accentCol = _getAccentColor(widget.goal.category);
    final user = FirebaseAuth.instance.currentUser;

    // Helper to determine image provider for the avatar
    ImageProvider? getAvatarImage() {
      if (_userPhotoBase64 != null && _userPhotoBase64!.isNotEmpty) {
        try {
          return MemoryImage(base64Decode(_userPhotoBase64!));
        } catch (e) {
          // If base64 is corrupt, fall through
        }
      }
      if (user?.photoURL != null) {
        return NetworkImage(user!.photoURL!);
      }
      return null;
    }

    // Determine name to display
    final displayName = _userName ?? user?.displayName ?? "Me";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Share Progress",
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: _isPosting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Post", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. User Header & Visibility Selector
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: getAvatarImage(),
                  child: getAvatarImage() == null
                      ? Text(displayName.isNotEmpty ? displayName[0] : "U", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),

                      // --- DROPDOWN ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PostVisibility>(
                            value: _visibility,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey),
                            items: [
                              DropdownMenuItem(
                                value: PostVisibility.all,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.public, size: 14, color: Colors.blue),
                                    const SizedBox(width: 6),
                                    Text("Public", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: PostVisibility.private,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text("Private", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _visibility = v!),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),

            const SizedBox(height: 24),

            // 2. Main Input
            TextField(
              controller: _contentCtrl,
              maxLines: null,
              minLines: 3,
              style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black87),
              decoration: const InputDecoration(
                hintText: "Share your thoughts, struggles, or a small victory...",
                hintStyle: TextStyle(color: Colors.black38),
                border: InputBorder.none,
              ),
            ),

            const SizedBox(height: 24),

            // 3. The "Ticket" Attachment
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentCol.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                            widget.goal.category.toUpperCase(),
                            style: TextStyle(color: accentCol, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.flag_rounded, color: accentCol, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.goal.title,
                    style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                      "${widget.goal.subGoals.length} milestones defined",
                      style: TextStyle(color: accentCol.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 4. Tags Section
            const Text("Add Tags", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._tags.map((t) => Chip(
                  label: Text("#$t"),
                  labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
                  backgroundColor: AppColors.primary.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                  onDeleted: () => setState(() => _tags.remove(t)),
                )),

                Container(
                  width: 100,
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _tagCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: "+ tag",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(bottom: 12),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}