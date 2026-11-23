import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/goal.dart';

class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Create Post
  Future<void> createPost(Post post) async {
    await _db.collection('posts').doc(post.id).set(post.toMap());
  }


  // 2. Stream Feed (FIXED: Filtering & Sorting)
  // 2. Stream Feed (FIXED: Explore only shows Public posts)
  // 2. Stream Feed (FIXED: Explore only shows Public posts)
  Stream<List<Post>> getFeed(PostVisibility filter, String currentUserId) {
    Query query = _db.collection('posts');

    if (filter == PostVisibility.private) {
      // SCENARIO 1: "My Posts" Tab
      // Logic: Show ALL posts created by me (even private ones)
      query = query.where('creatorId', isEqualTo: currentUserId);

    } else {
      // SCENARIO 2: "Explore" Tab (PostVisibility.all)
      // Logic: Show ONLY posts where visibility is 'all' (Public)
      // This filters out 'private' and 'friends' posts from the main feed
      query = query.where('visibility', isEqualTo: 'all');
    }

    // COMMON: Sort by latest
    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Post.fromDoc(doc)).toList();
    });
  }

  // 3. Toggle Like (FIXED: arrayUnion)
  Future<void> toggleLike(String postId, String userId) async {
    final ref = _db.collection('posts').doc(postId);
    final doc = await ref.get();
    if (!doc.exists) return;

    final List likes = List.from(doc.data()?['likes'] ?? []);
    if (likes.contains(userId)) {
      // Remove
      await ref.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      // Add (Use arrayUnion, NOT arrayAdd)
      await ref.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }

  // 4. ADOPT GOAL LOGIC (FIXED: Goal Instantiation)
  Future<void> adoptGoal(String userId, Map<String, dynamic> sourceData) async {
    final newId = const Uuid().v4();
    final now = DateTime.now();

    // Reconstruct subgoals
    List<dynamic> rawSubs = sourceData['subGoals'] ?? [];
    List<SubGoal> cleanSubs = rawSubs.map((s) {
      return SubGoal(
          id: const Uuid().v4(),
          title: s['title'] ?? 'Step',
          completed: false,
          dueDate: null
      );
    }).toList();

    final newGoal = Goal(
      id: newId,
      userId: userId,
      title: sourceData['title'],
      description: sourceData['description'] ?? '',
      category: sourceData['category'] ?? 'General',
      status: GoalStatus.inProgress,
      subGoals: cleanSubs,
      createdAt: now,
      updatedAt: now,
      endDate: null,
      associatedPeople: [],
      locationName: null,
      latitude: null,
      longitude: null,

      // --- ADDED MISSING REQUIRED FIELDS ---
      startDate: now, // Start today
      completedAt: null, // Not completed yet
      convertedToAchievement: false, // Not an achievement yet
    );

    // Save to User's Goal Collection
    // Changed .toDoc() to .toMap() because your model uses toMap()
    await _db.collection('users')
        .doc(userId)
        .collection('goals')
        .doc(newId)
        .set(newGoal.toMap());
  }

  // ... inside PostService class

  // 1. Stream of comments for a specific post
  Stream<List<Comment>> getComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Comment.fromDoc(doc)).toList());
  }

  // 2. Add a comment and increment the counter atomically
  Future<void> addComment(String postId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = _db.batch();

    // A. Create the comment reference
    final commentRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    final commentData = {
      'id': commentRef.id,
      'postId': postId,
      'userId': user.uid,
      'userName': user.displayName ?? 'User', // Ensure you save this in Auth
      'userPhoto': user.photoURL,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    batch.set(commentRef, commentData);

    // B. Increment the post's comment count
    final postRef = _db.collection('posts').doc(postId);
    batch.update(postRef, {
      'commentCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // 5. Delete Post
  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  // 6. Update Post (Expanded)
  Future<void> updatePost(String postId, String newContent, List<String> newTags, PostVisibility newVisibility) async {
    await _db.collection('posts').doc(postId).update({
      'content': newContent,
      'tags': newTags,
      'visibility': newVisibility.name,
      // We don't update the goal data (refData) as that remains constant history
    });
  }


}