import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/life_stage.dart';

class LifeStageService {
	final FirebaseFirestore _db;
	LifeStageService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

	CollectionReference<Map<String, dynamic>> _stages(String userId) =>
		_db.collection('users').doc(userId).collection('lifeStages');

	Future<LifeStage> create(String userId, LifeStage s) async {
		final data = s.toMap();
		final ref = await _stages(userId).add(data);
		final snap = await ref.get();
		return LifeStage.fromDoc(snap as DocumentSnapshot<Map<String, dynamic>>);
	}

	Future<void> update(String userId, LifeStage s) async {
		await _stages(userId).doc(s.id).update(s.toMap());
	}

	Future<void> delete(String userId, String id) async {
		await _stages(userId).doc(id).delete();
	}

	Stream<List<LifeStage>> stream(String userId) {
		return _stages(userId)
			.orderBy('sortOrder', descending: false)
			.snapshots()
			.map((s) => s.docs.map((d) => LifeStage.fromDoc(d)).toList());
	}
}


