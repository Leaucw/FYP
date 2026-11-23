import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/journal_entry.dart';

class JournalService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No logged in user");
    return _firestore.collection("users").doc(user.uid).collection("journals");
  }

  // CREATE
  Future<String> addEntry({
    required String title,
    required String content,
    required String? emotion,             // ⭐ NEW
    List<String> photos = const [],
    bool isFavorite = false,
    DateTime? futureOpenDate,
  }) async {
    final doc = _col().doc();
    final wordCount = content.trim().split(RegExp(r"\s+")).length;

    await doc.set({
      "title": title,
      "content": content,
      "emotion": emotion,                 // ⭐ NEW FIELD
      "createdAt": DateTime.now(),
      "photos": photos,
      "tags": [],                         // 🔥 REMOVE old tags system
      "isFavorite": isFavorite,
      "isArchived": false,
      "wordCount": wordCount,
      "futureOpenDate": futureOpenDate,
    });

    return doc.id;
  }

  // UPDATE
  Future<void> updateEntry({
    required String id,
    required String title,
    required String content,
    required String? emotion,           // ⭐ NEW
    List<String>? photos,
    bool? isFavorite,
    bool? isArchived,
    DateTime? futureOpenDate,
  }) async {
    final wordCount = content.trim().split(RegExp(r"\s+")).length;

    final Map<String, dynamic> data = {
      "title": title,
      "content": content,
      "emotion": emotion,               // ⭐ NEW FIELD
      "photos": photos,
      "isFavorite": isFavorite,
      "wordCount": wordCount,
      "futureOpenDate": futureOpenDate,
    };

    // Only update archive if it’s passed
    if (isArchived != null) data["isArchived"] = isArchived;

    // Clean nulls
    data.removeWhere((key, value) => value == null);

    await _col().doc(id).update(data);
  }

  // DELETE
  Future<void> deleteEntry(String id) async {
    await _col().doc(id).delete();
  }

  // FAVORITE
  Future<void> toggleFavorite(String id, bool current) async {
    await _col().doc(id).update({"isFavorite": !current});
  }

  // ARCHIVE
  Future<void> archiveEntry(String id) async {
    await _col().doc(id).update({"isArchived": true});
  }

  Future<void> unarchiveEntry(String id) async {
    await _col().doc(id).update({"isArchived": false});
  }

  // GET ALL
  Future<List<JournalEntry>> getAllEntries() async {
    final snap = await _col()
        .where("isArchived", isEqualTo: false)
        .orderBy("createdAt", descending: true)
        .get();

    return snap.docs.map((d) => JournalEntry.fromDoc(d)).toList();
  }

  // GET ARCHIVED
  Future<List<JournalEntry>> getArchivedEntries() async {
    final snap =
    await _col().where("isArchived", isEqualTo: true).get();

    return snap.docs.map((d) => JournalEntry.fromDoc(d)).toList();
  }

  // SEARCH (title / content / emotion)
  Future<List<JournalEntry>> searchEntries(String query) async {
    final all = await getAllEntries();
    final q = query.toLowerCase();

    return all.where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.content.toLowerCase().contains(q) ||
          e.emotion.toLowerCase().contains(q);
    }).toList();
  }
}
