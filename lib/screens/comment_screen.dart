// Add this class at the bottom of social_hub_screen.dart
// Don't forget to import '../models/comment.dart';

import 'dart:convert'; // Required for Base64
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for fetching
import 'package:intl/intl.dart';

import '../models/comment.dart';
import '../services/post_service.dart';
import '../theme/app_colors.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  const CommentsBottomSheet({super.key, required this.postId});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _controller = TextEditingController();
  bool _isComposing = false;

  void _handleSubmitted() {
    if (_controller.text.trim().isEmpty) return;

    // Send comment
    // Note: If your PostService supports passing custom name/photo, update it there.
    // Since we are fetching dynamically in the list below, the display will be correct
    // regardless of what snapshot is saved initially.
    PostService().addComment(widget.postId, _controller.text);

    // Clear input
    _controller.clear();
    setState(() => _isComposing = false);

    // Close keyboard (optional, keeps user in flow if removed)
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // calculate height to handle keyboard
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85, // Max 85% screen height
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1),

          // Comments List
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: PostService().getComments(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text("Be the first to comment!",
                        style: TextStyle(color: Colors.grey.shade400)),
                  );
                }

                final comments = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return _CommentItem(comment: comments[index]);
                  },
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), // Extra bottom padding
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 5)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (val) => setState(() => _isComposing = val.trim().isNotEmpty),
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isComposing ? AppColors.primary : Colors.grey.shade200,
                  child: IconButton(
                    icon: Icon(Icons.send_rounded, size: 18, color: _isComposing ? Colors.white : Colors.grey),
                    onPressed: _isComposing ? _handleSubmitted : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- NEW WIDGET: Fetches User Data for Each Comment ---
class _CommentItem extends StatelessWidget {
  final Comment comment;
  const _CommentItem({required this.comment});

  /// Fetches the author's latest profile data
  Future<Map<String, dynamic>?> _fetchAuthorData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(comment.userId)
          .get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  /// Helper to decode Base64 or use Network Image
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchAuthorData(),
      builder: (context, snapshot) {
        // Defaults (fallback to data stored in comment object)
        String displayName = comment.userName;
        ImageProvider? avatar = _getAvatarImage(comment.userPhoto);

        // If we successfully fetched real-time data, use that
        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!;
          if (data['name'] != null) displayName = data['name'];
          // Prioritize 'photoBase64' from user doc, else fallback
          if (data['photoBase64'] != null && data['photoBase64'].toString().isNotEmpty) {
            avatar = _getAvatarImage(data['photoBase64']);
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: avatar,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: avatar == null
                    ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            DateFormat.MMMd().format(comment.createdAt),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(comment.text, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}