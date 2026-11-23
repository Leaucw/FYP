import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalStatus { inProgress, completed, missed }

GoalStatus goalStatusFromString(String value) {
	switch (value) {
		case 'inProgress':
			return GoalStatus.inProgress;
		case 'completed':
			return GoalStatus.completed;
		case 'missed':
			return GoalStatus.missed;
		default:
			return GoalStatus.inProgress;
	}
}

String goalStatusToString(GoalStatus status) {
	switch (status) {
		case GoalStatus.inProgress:
			return 'inProgress';
		case GoalStatus.completed:
			return 'completed';
		case GoalStatus.missed:
			return 'missed';
	}
}

class SubGoal {
	final String id;
	final String title;
	final bool completed;
	final DateTime? dueDate;

	SubGoal({
		required this.id,
		required this.title,
		required this.completed,
		this.dueDate,
	});

	SubGoal copyWith({
		String? id,
		String? title,
		bool? completed,
		DateTime? dueDate,
	}) {
		return SubGoal(
			id: id ?? this.id,
			title: title ?? this.title,
			completed: completed ?? this.completed,
			dueDate: dueDate ?? this.dueDate,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'title': title,
			'completed': completed,
			'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
		};
	}

	factory SubGoal.fromMap(Map<String, dynamic> map) {
		return SubGoal(
			id: map['id'] as String,
			title: map['title'] as String,
			completed: (map['completed'] as bool?) ?? false,
			dueDate: (map['dueDate'] is Timestamp) ? (map['dueDate'] as Timestamp).toDate() : null,
		);
	}
}

class Goal {
	final String id;
	final String userId;
	final String title;
	final String description;
	final String category;
	final DateTime? startDate;
	final DateTime? endDate;
	final DateTime? completedAt;
	final String? locationName;
	final double? latitude;
	final double? longitude;
	final List<String> associatedPeople;
	final GoalStatus status;
	final List<SubGoal> subGoals;
	final bool convertedToAchievement;
	final DateTime createdAt;
	final DateTime updatedAt;

	Goal({
		required this.id,
		required this.userId,
		required this.title,
		required this.description,
		required this.startDate,
		required this.endDate,
		required this.completedAt,
		required this.category,
		required this.locationName,
		required this.latitude,
		required this.longitude,
		required this.associatedPeople,
		required this.status,
		required this.subGoals,
		required this.convertedToAchievement,
		required this.createdAt,
		required this.updatedAt,
	});

	Goal copyWith({
		String? id,
		String? userId,
		String? title,
		String? description,
		DateTime? startDate,
		DateTime? endDate,
		DateTime? completedAt,
		String? category,
		String? locationName,
		double? latitude,
		double? longitude,
		List<String>? associatedPeople,
		GoalStatus? status,
		List<SubGoal>? subGoals,
		bool? convertedToAchievement,
		DateTime? createdAt,
		DateTime? updatedAt,
	}) {
		return Goal(
			id: id ?? this.id,
			userId: userId ?? this.userId,
			title: title ?? this.title,
			description: description ?? this.description,
			startDate: startDate ?? this.startDate,
			endDate: endDate ?? this.endDate,
			completedAt: completedAt ?? this.completedAt,
			category: category ?? this.category,
			locationName: locationName ?? this.locationName,
			latitude: latitude ?? this.latitude,
			longitude: longitude ?? this.longitude,
			associatedPeople: associatedPeople ?? this.associatedPeople,
			status: status ?? this.status,
			subGoals: subGoals ?? this.subGoals,
			convertedToAchievement: convertedToAchievement ?? this.convertedToAchievement,
			createdAt: createdAt ?? this.createdAt,
			updatedAt: updatedAt ?? this.updatedAt,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'userId': userId,
			'title': title,
			'description': description,
			'category': category,
			'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
			'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
			'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
			'locationName': locationName,
			'latitude': latitude,
			'longitude': longitude,
			'associatedPeople': associatedPeople,
			'status': goalStatusToString(status),
			'subGoals': subGoals.map((g) => g.toMap()).toList(),
			'convertedToAchievement': convertedToAchievement,
			'createdAt': Timestamp.fromDate(createdAt),
			'updatedAt': Timestamp.fromDate(updatedAt),
		};
	}

	factory Goal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
		final data = doc.data() ?? {};
		return Goal(
			id: doc.id,
			userId: data['userId'] as String,
			title: data['title'] as String? ?? '',
			description: data['description'] as String? ?? '',
			category: data['category'] as String? ?? 'Personal Growth',
			startDate: data['startDate'] is Timestamp ? (data['startDate'] as Timestamp).toDate() : null,
			endDate: data['endDate'] is Timestamp ? (data['endDate'] as Timestamp).toDate() : null,
			completedAt: data['completedAt'] is Timestamp ? (data['completedAt'] as Timestamp).toDate() : null,
			locationName: data['locationName'] as String?,
			latitude: (data['latitude'] as num?)?.toDouble(),
			longitude: (data['longitude'] as num?)?.toDouble(),
			associatedPeople: (data['associatedPeople'] as List?)?.map((e) => e.toString()).toList() ?? const [],
			status: goalStatusFromString(data['status'] as String? ?? 'inProgress'),
			subGoals: (data['subGoals'] as List?)
					?.map((e) => SubGoal.fromMap(Map<String, dynamic>.from(e as Map)))
					.toList() ??
					const [],
			convertedToAchievement: (data['convertedToAchievement'] as bool?) ?? false,
			createdAt: (data['createdAt'] as Timestamp).toDate(),
			updatedAt: (data['updatedAt'] as Timestamp).toDate(),
		);
	}
}



