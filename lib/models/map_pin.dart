class MapPin {
	final String id;
	final String userId;
	final String title;
	final String? description;
	final String? relatedAchievementId;
	final String? relatedGoalId;
	final String? locationName;
	final double latitude;
	final double longitude;

	MapPin({
		required this.id,
		required this.userId,
		required this.title,
		required this.description,
		required this.relatedAchievementId,
		required this.relatedGoalId,
		required this.locationName,
		required this.latitude,
		required this.longitude,
	});

	Map<String, dynamic> toMap() {
		return {
			'userId': userId,
			'title': title,
			'description': description,
			'relatedAchievementId': relatedAchievementId,
			'relatedGoalId': relatedGoalId,
			'locationName': locationName,
			'latitude': latitude,
			'longitude': longitude,
		};
	}

	factory MapPin.fromMap(String id, Map<String, dynamic> data) {
		return MapPin(
			id: id,
			userId: data['userId'] as String,
			title: data['title'] as String? ?? '',
			description: data['description'] as String?,
			relatedAchievementId: data['relatedAchievementId'] as String?,
			relatedGoalId: data['relatedGoalId'] as String?,
			locationName: data['locationName'] as String?,
			latitude: (data['latitude'] as num).toDouble(),
			longitude: (data['longitude'] as num).toDouble(),
		);
	}
}


