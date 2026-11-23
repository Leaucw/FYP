import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal.dart';
import 'map_pin_service.dart';

class GoalService {
	final FirebaseFirestore _db;
	final MapPinService _mapPins;

	GoalService({FirebaseFirestore? db, MapPinService? mapPinService})
			: _db = db ?? FirebaseFirestore.instance,
				_mapPins = mapPinService ?? MapPinService(db: db ?? FirebaseFirestore.instance);

	CollectionReference<Map<String, dynamic>> _goals(String userId) =>
			_db.collection('users').doc(userId).collection('goals');

	Future<Goal> createGoal(String userId, Goal goal) async {
		final data = goal.toMap();
		data.remove('id');
		final ref = await _goals(userId).add(data);
		final snap = await ref.get();
		final saved = Goal.fromDoc(snap as DocumentSnapshot<Map<String, dynamic>>);
		await _syncMapPin(saved);
		return saved;
	}

	Future<void> updateGoal(String userId, Goal goal) async {
		await _goals(userId).doc(goal.id).update({
			...goal.toMap(),
			'updatedAt': Timestamp.fromDate(DateTime.now()),
		});
		await _syncMapPin(goal);
	}

	Future<void> deleteGoal(String userId, String goalId) async {
		await _goals(userId).doc(goalId).delete();
		await _mapPins.deleteForGoal(userId, goalId);
	}

	Stream<List<Goal>> streamGoals(String userId) {
		return _goals(userId)
				.orderBy('createdAt', descending: true)
				.snapshots()
				.map((s) => s.docs.map((d) => Goal.fromDoc(d)).toList());
	}

	Future<void> addSubGoal(String userId, String goalId, SubGoal subGoal) async {
		final doc = await _goals(userId).doc(goalId).get();
		final goal = Goal.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
		final updated = goal.copyWith(
			subGoals: [...goal.subGoals, subGoal],
			updatedAt: DateTime.now(),
		);
		await updateGoal(userId, updated);
	}

	Future<void> updateSubGoal(String userId, String goalId, SubGoal subGoal) async {
		final doc = await _goals(userId).doc(goalId).get();
		final goal = Goal.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
		final updatedList = goal.subGoals.map((g) => g.id == subGoal.id ? subGoal : g).toList();
		final updated = goal.copyWith(subGoals: updatedList, updatedAt: DateTime.now());
		await updateGoal(userId, updated);
	}

	Future<void> removeSubGoal(String userId, String goalId, String subGoalId) async {
		final doc = await _goals(userId).doc(goalId).get();
		final goal = Goal.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
		final updatedList = goal.subGoals.where((g) => g.id != subGoalId).toList();
		final updated = goal.copyWith(subGoals: updatedList, updatedAt: DateTime.now());
		await updateGoal(userId, updated);
	}

	Future<void> _syncMapPin(Goal goal) async {
		if (goal.status == GoalStatus.completed && goal.latitude != null && goal.longitude != null) {
			await _mapPins.upsertForGoal(goal);
		} else {
			await _mapPins.deleteForGoal(goal.userId, goal.id);
		}
	}
}


