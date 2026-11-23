import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
	final String id;
	final String userId;
	final String title;
	final String description;
	final DateTime date;
	final String category;
	final List<String> associatedPeople;
	final String? lifeStageId;
	final String? locationName;
	final double? latitude;
	final double? longitude;
	final String? sourceGoalId;

	final DateTime createdAt;
	final DateTime updatedAt;

	final String? photoBase64;
	final int points;

	// ⭐ NEW FIELD
	final bool sharedSimplified;

	// ⭐ NEW FIELDS for completed with
	final String? completedWithId;
	final String? completedWithName;
	final String? completedWithAppUid;

	Achievement({
		required this.id,
		required this.userId,
		required this.title,
		required this.description,
		required this.date,
		required this.category,
		required this.associatedPeople,
		required this.lifeStageId,
		required this.locationName,
		required this.latitude,
		required this.longitude,
		required this.sourceGoalId,
		required this.createdAt,
		required this.updatedAt,
		required this.points,
		this.photoBase64,

		// ⭐ NEW:
		this.sharedSimplified = false,
		this.completedWithId,
		this.completedWithName,
		this.completedWithAppUid,
	});

	// SAVE --------------------------------------------------------
	Map<String, dynamic> toMap() {
		return {
			'userId': userId,
			'title': title,
			'description': description,
			'date': Timestamp.fromDate(date),
			'category': category,
			'associatedPeople': associatedPeople,
			'lifeStageId': lifeStageId,
			'locationName': locationName,
			'latitude': latitude,
			'longitude': longitude,
			'sourceGoalId': sourceGoalId,
			'createdAt': Timestamp.fromDate(createdAt),
			'updatedAt': Timestamp.fromDate(updatedAt),
			'photoBase64': photoBase64,
			'points': points,

			// ⭐ NEW
			'sharedSimplified': sharedSimplified,
			'completedWithId': completedWithId,
			'completedWithName': completedWithName,
			'completedWithAppUid': completedWithAppUid,
		};
	}

	// LOAD --------------------------------------------------------
	factory Achievement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
		final data = doc.data() ?? {};

		return Achievement(
			id: doc.id,
			userId: data['userId'] ?? '',
			title: data['title'] ?? '',
			description: data['description'] ?? '',
			date: (data['date'] as Timestamp).toDate(),
			category: data['category'] ?? '',
			associatedPeople: (data['associatedPeople'] as List?)?.map((e) => e.toString()).toList() ?? [],

			lifeStageId: data['lifeStageId'],
			locationName: data['locationName'],
			latitude: (data['latitude'] as num?)?.toDouble(),
			longitude: (data['longitude'] as num?)?.toDouble(),
			sourceGoalId: data['sourceGoalId'],

			createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
			updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

			photoBase64: data['photoBase64'],
			points: (data['points'] as num?)?.toInt() ?? 0,

			// ⭐ NEW
			sharedSimplified: data['sharedSimplified'] ?? false,
			completedWithId: data['completedWithId'],
			completedWithName: data['completedWithName'],
			completedWithAppUid: data['completedWithAppUid'],
		);
	}
}
