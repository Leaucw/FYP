import 'package:cloud_firestore/cloud_firestore.dart';

enum PostVisibility { all, friends, private }
enum PostType { goal, achievement }

class Post {
  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorPhoto;
  final String content;
  final List<String> tags;
  final PostVisibility visibility;
  final PostType type;

  // Interaction Stats
  final List<String> likes;
  final int commentCount;
  final DateTime createdAt;

  // The Embedded Content
  final String refId;
  final Map<String, dynamic> refData;

  Post({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorPhoto,
    required this.content,
    required this.tags,
    required this.visibility,
    required this.type,
    this.likes = const [],
    this.commentCount = 0,
    required this.createdAt,
    required this.refId,
    required this.refData,
  });

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorPhoto': creatorPhoto,
      'content': content,
      'tags': tags,
      // Save simply as the name (e.g., "all", "private")
      'visibility': visibility.name,
      'type': type.name,
      'likes': likes,
      'commentCount': commentCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'refId': refId,
      'refData': refData,
    };
  }

  factory Post.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Post(
      id: doc.id,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? 'Anonymous',
      creatorPhoto: data['creatorPhoto'],
      content: data['content'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),

      // --- CRASH PREVENTERS ---
      // If visibility is missing/wrong, default to .all
      visibility: PostVisibility.values.firstWhere(
              (e) => e.name == data['visibility'],
          orElse: () => PostVisibility.all
      ),
      // If type is missing, default to .goal
      type: PostType.values.firstWhere(
              (e) => e.name == data['type'],
          orElse: () => PostType.goal
      ),
      // ------------------------

      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] ?? 0,

      // Handle missing dates safely
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),

      refId: data['refId'] ?? '',
      refData: Map<String, dynamic>.from(data['refData'] ?? {}),
    );
  }
}