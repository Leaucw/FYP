import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal.dart';
import '../services/goal_service.dart';
import '../theme/app_colors.dart';

class ArchivedGoalsScreen extends StatelessWidget {
	final _auth = FirebaseAuth.instance;
	final _service = GoalService(db: FirebaseFirestore.instance);

	ArchivedGoalsScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final user = _auth.currentUser;
		if (user == null) return const Scaffold(body: Center(child: Text('Please sign in')));

		return Scaffold(
			appBar: AppBar(
				title: const Text('Archived Goals'),
				backgroundColor: AppColors.primary,
				foregroundColor: Colors.white,
			),
			body: StreamBuilder<List<Goal>>(
				stream: _service.streamGoals(user.uid),
				builder: (context, snapshot) {
					if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
					final goals = snapshot.data!
						.where((g) => g.status == GoalStatus.completed)
						.toList()
						..sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));
					if (goals.isEmpty) return const Center(child: Text('No archived goals yet'));
					return ListView.separated(
						padding: const EdgeInsets.all(12),
						itemCount: goals.length,
						separatorBuilder: (_, __) => const SizedBox(height: 8),
						itemBuilder: (context, i) {
							final g = goals[i];
							return ListTile(
								title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w600)),
								subtitle: Text((g.completedAt ?? g.updatedAt).toLocal().toIso8601String().split('T').first),
								trailing: g.locationName != null ? const Icon(Icons.place) : null,
							);
						},
					);
				},
			),
		);
	}
}


