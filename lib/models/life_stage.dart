import 'package:cloud_firestore/cloud_firestore.dart';

class LifeStage {
	final String id;
	final String userId;
	final String name;
	final DateTime? startDate;
	final DateTime? endDate;
	final int sortOrder;
	final int colorValue;

	LifeStage({
		required this.id,
		required this.userId,
		required this.name,
		required this.startDate,
		required this.endDate,
		required this.sortOrder,
		required this.colorValue,
	});

	Map<String, dynamic> toMap() {
		return {
			'userId': userId,
			'name': name,
			'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
			'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
			'sortOrder': sortOrder,
			'colorValue': colorValue,
		};
	}

	factory LifeStage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
		final data = doc.data() ?? {};
		return LifeStage(
			id: doc.id,
			userId: data['userId'] as String,
			name: data['name'] as String? ?? '',
			startDate: data['startDate'] is Timestamp ? (data['startDate'] as Timestamp).toDate() : null,
			endDate: data['endDate'] is Timestamp ? (data['endDate'] as Timestamp).toDate() : null,
			sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
			colorValue: (data['colorValue'] as num?)?.toInt() ?? 0xFF90CAF9,
		);
	}
}


