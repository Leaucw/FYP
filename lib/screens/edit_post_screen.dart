import 'dart:convert'; // Required for Base64 decoding
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Required to fetch custom avatar
import '../models/post.dart';
import '../services/post_service.dart';
import '../theme/app_colors.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;
  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _contentCtrl;
  late TextEditingController _tagCtrl;
  late List<String> _tags;
  late PostVisibility _visibility;
  bool _isSaving = false;

  // Store the fetched User details
  String? _userPhotoBase64;
  String? _userName;

  @override
  void initState() {
    super.initState();
    // 1. Pre-fill data from existing post
    _contentCtrl = TextEditingController(text: widget.post.content);
    _tagCtrl = TextEditingController();
    _tags = List.from(widget.post.tags);
    _visibility = widget.post.visibility;

    // 2. Fetch the latest user profile data
    _fetchUserData();
  }

  /// Fetches the current user's custom name and avatar from Firestore
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

  @override
  void dispose() {
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final t = _tagCtrl.text.trim().replaceAll('#', '');
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _tagCtrl.clear();
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_contentCtrl.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await PostService().updatePost(
          widget.post.id,
          _contentCtrl.text.trim(),
          _tags,
          _visibility
      );

      if (mounted) {
        Navigator.pop(context); // Close screen
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Post updated successfully!"))
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error updating: $e"))
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final category = widget.post.refData['category'];
    final bgCol = _getCategoryColor(category);
    final accentCol = _getAccentColor(category);

    // Helper: Determine which image provider to use
    ImageProvider? getAvatarImage() {
      // 1. Try Base64 from Firestore fetch
      if (_userPhotoBase64 != null && _userPhotoBase64!.isNotEmpty) {
        try {
          return MemoryImage(base64Decode(_userPhotoBase64!));
        } catch (e) {
          // ignore error
        }
      }
      // 2. Try Auth Photo URL
      if (user?.photoURL != null) {
        return NetworkImage(user!.photoURL!);
      }
      // 3. Fallback to null
      return null;
    }

    // Determine the name to display
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
        title: const Text("Edit Post",
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. User Header & Visibility
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

                      // Dropdown (Public/Private)
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

            // 2. Content Input
            TextField(
              controller: _contentCtrl,
              maxLines: null,
              minLines: 3,
              style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black87),
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
            ),

            const SizedBox(height: 24),

            // 3. The "Ticket" (Goal Preview - Read Only)
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
                    widget.post.refData['title'] ?? "Unknown",
                    style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                      "${(widget.post.refData['subGoals'] as List).length} milestones defined",
                      style: TextStyle(color: accentCol.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 4. Tags Management
            const Text("Edit Tags", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
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