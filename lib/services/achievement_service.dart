import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/achievement.dart';
import '../utils/achievement_config.dart';

class AchievementService {
	final FirebaseFirestore _db;
	final FirebaseAuth _auth;

	AchievementService({
		FirebaseFirestore? db,
		FirebaseAuth? auth,
	})  : _db = db ?? FirebaseFirestore.instance,
				_auth = auth ?? FirebaseAuth.instance;

	String get uid => _auth.currentUser!.uid;

	CollectionReference<Map<String, dynamic>> _achievements(String userUid) =>
			_db.collection("users").doc(userUid).collection("achievements");

	CollectionReference<Map<String, dynamic>> _monthly(String userUid) =>
			_db.collection("users").doc(userUid).collection("monthlyScores");

	DocumentReference<Map<String, dynamic>> _user(String userUid) =>
			_db.collection("users").doc(userUid);

	String _monthKey(DateTime d) =>
			"${d.year}-${d.month.toString().padLeft(2, '0')}";

	Future<int> _getMonthlyPoints(String userUid, DateTime date) async {
		final doc = await _monthly(userUid).doc(_monthKey(date)).get();
		return doc.exists ? (doc.data()?['totalPoints'] ?? 0) as int : 0;
	}

	// IMAGE PICK
	Future<String?> pickImageBase64() async {
		final picker = ImagePicker();
		final picked = await picker.pickImage(source: ImageSource.gallery);
		if (picked == null) return null;

		File file = File(picked.path);

		final compressed = await FlutterImageCompress.compressAndGetFile(
			file.absolute.path,
			file.path.replaceAll(".jpg", "_compressed.jpg"),
			quality: 40,
			minWidth: 200,
			minHeight: 200,
		);

		final finalFile = compressed != null ? File(compressed.path) : file;
		final bytes = await finalFile.readAsBytes();

		return base64Encode(bytes);
	}

	// AWARD POINTS
	Future<void> _awardPointsToUser(
			String targetUid, AchievementCategory category, DateTime date) async {
		final basePoints = AchievementConfig.basePoints(category);
		final monthKey = _monthKey(date);
		final currentMonth = await _getMonthlyPoints(targetUid, date);

		final remaining = AchievementConfig.monthlyCap - currentMonth;
		final awarded =
		remaining > 0 ? (basePoints <= remaining ? basePoints : remaining) : 0;

		await _monthly(targetUid).doc(monthKey).set(
			{"totalPoints": currentMonth + awarded},
			SetOptions(merge: true),
		);

		await _updateBadge(targetUid);
	}

	// NOTIFICATION
	Future<void> _createInAppNotification({
		required String targetUid,
		required String fromUid,
		required String achievementId,
		required String title,
		required String body,
	}) async {
		await _db
				.collection("users")
				.doc(targetUid)
				.collection("notifications")
				.add({
			"title": title,
			"body": body,
			"achievementId": achievementId,
			"fromUid": fromUid,
			"createdAt": Timestamp.now(),
			"read": false,
		});
	}

	// FCM PUSH
	Future<void> _sendPushNotification({
		required String targetUid,
		required String title,
		required String body,
	}) async {
		final userDoc = await _db.collection("users").doc(targetUid).get();
		final token = userDoc.data()?['fcmToken'] ?? "";

		if (token.isEmpty) return;

		await _db.collection("pushMessages").add({
			"token": token,
			"title": title,
			"body": body,
		});
	}

	// ------------------------------------------------------------
	// CREATE ACHIEVEMENT + SHARED COPY
	// ------------------------------------------------------------
	Future<void> addAchievement({
		required String title,
		required String description,
		required AchievementCategory category,
		required DateTime date,
		String? photoBase64,
		String? completedWithId,
		String? completedWithName,
		String? completedWithAppUid,
		String? locationName,
		double? latitude,
		double? longitude,
	}) async {
		final userUid = uid;

		final basePoints = AchievementConfig.basePoints(category);
		final monthKey = _monthKey(date);
		final currentMonth = await _getMonthlyPoints(userUid, date);

		final remaining = AchievementConfig.monthlyCap - currentMonth;
		final awarded =
		remaining > 0 ? (basePoints <= remaining ? basePoints : remaining) : 0;

		// MAIN ACHIEVEMENT
		final docRef = await _achievements(userUid).add({
			"userId": userUid,
			"title": title,
			"description": description,
			"category": AchievementConfig.categoryToString(category),
			"date": Timestamp.fromDate(date),
			"photoBase64": photoBase64 ?? "",
			"points": awarded,

			"completedWithId": completedWithId,
			"completedWithName": completedWithName ?? "",
			"completedWithAppUid": completedWithAppUid,
			"locationName": locationName,
			"latitude": latitude,
			"longitude": longitude,
			"sharedSimplified": false,
			"sharedFromId": null, // main achievement
			"createdAt": Timestamp.now(),
			"updatedAt": Timestamp.now(),
		});

		await _monthly(userUid).doc(monthKey).set(
			{"totalPoints": currentMonth + awarded},
			SetOptions(merge: true),
		);
		await _updateBadge(userUid);

		// ------------------------------------------------------------
		// CREATE SHARED COPY
		// ------------------------------------------------------------
		if (completedWithAppUid != null && completedWithAppUid.isNotEmpty) {
			await _awardPointsToUser(completedWithAppUid, category, date);

			final creatorName =
			(_auth.currentUser!.displayName != null &&
					_auth.currentUser!.displayName!.trim().isNotEmpty)
					? _auth.currentUser!.displayName!
					: userUid;  // fallback to creator UID
			final friendlyCreatorId = await getFriendlyUserId(userUid);

			await _achievements(completedWithAppUid).add({
				"userId": completedWithAppUid,
				"title": title,
				"description": "Completed together with $friendlyCreatorId",
				"category": AchievementConfig.categoryToString(category),
				"date": Timestamp.fromDate(date),
				"photoBase64": "",
				"points": awarded,

				"completedWithId": userUid,   // creator UID
				"completedWithName": creatorName, // creator NAME or UID
				"completedWithAppUid": userUid,   // creator UID

				"sharedSimplified": true,
				"sharedFromId": docRef.id,

				"createdAt": Timestamp.now(),
				"updatedAt": Timestamp.now(),
			});

			await _updateBadge(completedWithAppUid);

			await _createInAppNotification(
				targetUid: completedWithAppUid,
				fromUid: userUid,
				achievementId: docRef.id,
				title: "Achievement Completed!",
				body: "$completedWithName completed an achievement with you!",
			);

			await _sendPushNotification(
				targetUid: completedWithAppUid,
				title: "Achievement Completed!",
				body: "$completedWithName completed an achievement with you!",
			);
		}
	}

	// ------------------------------------------------------------
	// UPDATE ACHIEVEMENT + UPDATE SHARED COPY
	// ------------------------------------------------------------
	Future<void> updateAchievement(
			String id, {
				required String title,
				required String description,
				required AchievementCategory category,
				required DateTime date,
				String? photoBase64,
				String? completedWithId,
				String? completedWithName,
				String? completedWithAppUid,
				String? locationName,
				double? latitude,
				double? longitude,
			}) async {

		final userUid = uid;

		// 1️⃣ Load old achievement to detect if completedWith user changed
		final oldDoc = await _achievements(userUid).doc(id).get();
		final oldData = oldDoc.data()!;
		final oldSharedUid = oldData["completedWithAppUid"] ?? "";
		final friendlyCreatorId = await getFriendlyUserId(userUid);
		// -----------------------------------------------------
		// 2️⃣ Update main achievement (User1)
		// -----------------------------------------------------
		await _achievements(userUid).doc(id).update({
			"title": title,
			"description": description,
			"category": AchievementConfig.categoryToString(category),
			"date": Timestamp.fromDate(date),
			"photoBase64": photoBase64 ?? "",
			"completedWithId": completedWithId,
			"completedWithName": completedWithName,
			"completedWithAppUid": completedWithAppUid,
			"locationName": locationName,
			"latitude": latitude,
			"longitude": longitude,
			"updatedAt": Timestamp.now(),
		});

		// -----------------------------------------------------
		// 3️⃣ CASE A — User CHANGED the shared user
		// -----------------------------------------------------
		final userChangedPartner =
				(oldSharedUid != completedWithAppUid) &&
						(oldSharedUid.toString().isNotEmpty);

		if (userChangedPartner) {
			// DELETE OLD SHARED COPY FROM OLD USER
			final oldSnap = await _achievements(oldSharedUid)
					.where("sharedSimplified", isEqualTo: true)
					.where("sharedFromId", isEqualTo: id)
					.get();

			for (var doc in oldSnap.docs) {
				final pointsToRemove = (doc.data()["points"] ?? 0) as int;

				await doc.reference.delete();

				// deduct points
				final currentMonth = await _getMonthlyPoints(oldSharedUid, date);
				final monthKey = _monthKey(date);

				await _monthly(oldSharedUid).doc(monthKey).set(
					{"totalPoints": currentMonth - pointsToRemove},
					SetOptions(merge: true),
				);

				await _updateBadge(oldSharedUid);
			}
		}

		// -----------------------------------------------------
		// 3️⃣ CASE C — User removed the shared partner (set to None)
		// -----------------------------------------------------
		if ((completedWithAppUid == null || completedWithAppUid.isEmpty) &&
				oldSharedUid.toString().isNotEmpty) {

			final oldUid = oldSharedUid;

			// Find and delete the old shared achievement
			final oldSnap = await _achievements(oldUid)
					.where("sharedSimplified", isEqualTo: true)
					.where("sharedFromId", isEqualTo: id)
					.get();

			for (var doc in oldSnap.docs) {
				final sharedPoints = (doc.data()["points"] ?? 0) as int;

				// Delete shared achievement
				await doc.reference.delete();

				// Deduct points
				final currentMonth = await _getMonthlyPoints(oldUid, date);
				final monthKey = _monthKey(date);

				await _monthly(oldUid).doc(monthKey).set(
					{"totalPoints": currentMonth - sharedPoints},
					SetOptions(merge: true),
				);

				await _updateBadge(oldUid);
			}
		}

		// -----------------------------------------------------
		// 3️⃣ CASE D — Shared partner unchanged → update existing shared copy
		// -----------------------------------------------------
		if (completedWithAppUid != null &&
				completedWithAppUid.isNotEmpty &&
				completedWithAppUid == oldSharedUid) {

			final sameUserSnap = await _achievements(completedWithAppUid)
					.where("sharedSimplified", isEqualTo: true)
					.where("sharedFromId", isEqualTo: id)
					.get();

			// 🔥 Fetch creator friendly ID (user1, user2, etc.)
			final friendlyCreatorId = await getFriendlyUserId(userUid);

			// 🔥 If displayName is empty → fallback to friendly ID
			final creatorName =
			(_auth.currentUser!.displayName != null &&
					_auth.currentUser!.displayName!.trim().isNotEmpty)
					? _auth.currentUser!.displayName!
					: friendlyCreatorId;

			for (var doc in sameUserSnap.docs) {
				await doc.reference.update({
					"title": title,

					// 🔥 FIXED: show friendly creator name in shared copy
					"description": "Completed together with $creatorName",

					// 🔥 FIXED: update completedWith fields too
					"completedWithName": creatorName,
					"completedWithId": userUid,

					"category": AchievementConfig.categoryToString(category),
					"date": Timestamp.fromDate(date),
					"updatedAt": Timestamp.now(),
				});
			}
		}


		// -----------------------------------------------------
		// 4️⃣ CASE B — ADD NEW SHARED COPY (if new user selected)
		// -----------------------------------------------------
		if (completedWithAppUid != null && completedWithAppUid.isNotEmpty) {
			final newUid = completedWithAppUid;

			// 1️⃣ UPDATE existing shared copy if exists
			final updateSnap = await _achievements(newUid)
					.where("sharedSimplified", isEqualTo: true)
					.where("sharedFromId", isEqualTo: id)
					.get();

			// 🔥 Fetch friendly creator ID (user1, user2...)
			final friendlyCreatorId = await getFriendlyUserId(userUid);

			// 🔥 Use displayName if available, else fallback to friendly ID
			final creatorName =
			(_auth.currentUser!.displayName != null &&
					_auth.currentUser!.displayName!.trim().isNotEmpty)
					? _auth.currentUser!.displayName!
					: friendlyCreatorId;

			for (var doc in updateSnap.docs) {
				await doc.reference.update({
					"title": title,

					// 🔥 FIX: show friendly creator name
					"description": "Completed together with $creatorName",

					"completedWithName": creatorName,
					"completedWithId": userUid,

					"category": AchievementConfig.categoryToString(category),
					"date": Timestamp.fromDate(date),
					"updatedAt": Timestamp.now(),
				});
			}

			// 2️⃣ IF no shared copy → create a new one
			if (updateSnap.docs.isEmpty) {
				await _awardPointsToUser(newUid, category, date);

				await _achievements(newUid).add({
					"userId": newUid,
					"title": title,

					// 🔥 FIX: show friendly creator name
					"description": "Completed together with $creatorName",

					"category": AchievementConfig.categoryToString(category),
					"date": Timestamp.fromDate(date),
					"photoBase64": "",
					"points": AchievementConfig.basePoints(category),

					// 🔥 FIX: friendly creator info
					"completedWithId": userUid,
					"completedWithName": creatorName,
					"completedWithAppUid": userUid,

					"sharedSimplified": true,
					"sharedFromId": id,
					"createdAt": Timestamp.now(),
					"updatedAt": Timestamp.now(),
				});

				await _updateBadge(newUid);
			}
		}
	}



	// ------------------------------------------------------------
	// DELETE ACHIEVEMENT + DELETE SHARED COPY
	// ------------------------------------------------------------
	Future<void> deleteAchievement(Achievement a) async {
		final userUid = uid;

		// Delete main
		await _achievements(userUid).doc(a.id).delete();

		final monthKey = _monthKey(a.date);
		final current = await _getMonthlyPoints(userUid, a.date);

		await _monthly(userUid).doc(monthKey).set({
			"totalPoints": current - a.points,
		}, SetOptions(merge: true));

		await _updateBadge(userUid);

		// Delete shared copy
		if (a.completedWithAppUid != null && a.completedWithAppUid!.isNotEmpty) {
			final otherUid = a.completedWithAppUid!;

			final snap = await _achievements(otherUid)
					.where("sharedSimplified", isEqualTo: true)
					.where("sharedFromId", isEqualTo: a.id)
					.get();

			for (var doc in snap.docs) {
				await doc.reference.delete();

				final otherMonth = await _getMonthlyPoints(otherUid, a.date);
				await _monthly(otherUid).doc(monthKey).set({
					"totalPoints": otherMonth - a.points,
				}, SetOptions(merge: true));

				await _updateBadge(otherUid);
			}
		}
	}

	// ------------------------------------------------------------
// FRIENDLY USER ID FETCHER
// ------------------------------------------------------------
	Future<String> getFriendlyUserId(String uid) async {
		final snap = await _db.collection("users").doc(uid).get();
		if (!snap.exists) return uid;

		final data = snap.data();
		return data?["userId"] ?? uid;  // "user1", "user2", etc.
	}


	// ------------------------------------------------------------
	// STREAMS
	// ------------------------------------------------------------
	Stream<List<Achievement>> getAchievements() {
		return _achievements(uid)
				.orderBy("date", descending: true)
				.snapshots()
				.map((snap) =>
				snap.docs.map((d) => Achievement.fromDoc(d)).toList());
	}

	Stream<List<Achievement>> searchAchievements(String keyword) {
		keyword = keyword.toLowerCase().trim();
		return _achievements(uid).snapshots().map((snap) {
			final all = snap.docs.map((d) => Achievement.fromDoc(d)).toList();
			return all.where((a) {
				return a.title.toLowerCase().contains(keyword) ||
						a.description.toLowerCase().contains(keyword) ||
						a.category.toLowerCase().contains(keyword);
			}).toList();
		});
	}

	Stream<List<Achievement>> filterAchievements({
		AchievementCategory? category,
		int? month,
		int? year,
	}) {
		return _achievements(uid).snapshots().map((snap) {
			final all = snap.docs.map((d) => Achievement.fromDoc(d)).toList();
			return all.where((a) {
				bool match = true;
				if (category != null &&
						a.category != AchievementConfig.categoryToString(category))
					match = false;
				if (month != null && a.date.month != month) match = false;
				if (year != null && a.date.year != year) match = false;
				return match;
			}).toList();
		});
	}

	// ------------------------------------------------------------
	// BADGE UPDATE
	// ------------------------------------------------------------
	Future<void> _updateBadge(String userUid) async {
		final docs = await _achievements(userUid).get();
		int total = 0;

		for (var d in docs.docs) {
			total += ((d.data()['points'] ?? 0) as num).toInt();
		}

		final badge = AchievementConfig.badgeFor(total);

		await _user(userUid).set(
			{"totalPoints": total, "badgeLevel": badge},
			SetOptions(merge: true),
		);
	}

	Stream<List<Achievement>> stream(String userId) {
		return _achievements(userId)
				.orderBy('date', descending: true)
				.snapshots()
				.map((s) => s.docs.map((d) => Achievement.fromDoc(d)).toList());
	}

	Future<Achievement> create(String userId, Achievement a) async {
		final data = a.toMap();
		final ref = await _achievements(userId).add(data);
		final snap = await ref.get();
		return Achievement.fromDoc(snap as DocumentSnapshot<Map<String, dynamic>>);
	}
}
