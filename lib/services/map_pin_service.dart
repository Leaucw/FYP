import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/map_pin.dart';
import '../models/goal.dart';

class MapPinService {
	final FirebaseFirestore _db;
	MapPinService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

	CollectionReference<Map<String, dynamic>> _pins(String userId) =>
			_db.collection('users').doc(userId).collection('mapPins');

	Future<MapPin> create(String userId, MapPin pin) async {
		final data = pin.toMap();
		final ref = await _pins(userId).add(data);
		final snap = await ref.get();
		return MapPin.fromMap(snap.id, snap.data()!);
	}

	Future<void> update(String userId, MapPin pin) async {
		await _pins(userId).doc(pin.id).update(pin.toMap());
	}

	Future<void> delete(String userId, String id) async {
		await _pins(userId).doc(id).delete();
	}

	Stream<List<MapPin>> stream(String userId) {
		return _pins(userId)
				.snapshots()
				.map((s) => s.docs.map((d) => MapPin.fromMap(d.id, d.data())).toList());
	}

	Future<void> upsertForGoal(Goal goal) async {
		final data = MapPin(
			id: goal.id,
			userId: goal.userId,
			title: goal.title,
			description: goal.description,
			relatedAchievementId: null,
			relatedGoalId: goal.id,
			locationName: goal.locationName,
			latitude: goal.latitude ?? 0,
			longitude: goal.longitude ?? 0,
		).toMap();
		await _pins(goal.userId).doc(goal.id).set(data);
	}

	Future<void> deleteForGoal(String userId, String goalId) async {
		final ref = _pins(userId).doc(goalId);
		if ((await ref.get()).exists) {
			await ref.delete();
		}
	}
}


