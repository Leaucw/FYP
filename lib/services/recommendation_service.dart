class RecommendationService {
	static const Map<String, List<Map<String, String>>> _catalog = {
		'fitness': [
			{'title': 'Beginner Workout Guide', 'url': 'https://www.healthline.com/health/fitness-exercise/beginner-workout-plan'},
			{'title': 'How to build habits that stick', 'url': 'https://jamesclear.com/habits'},
		],
		'career': [
			{'title': 'Ace your next interview', 'url': 'https://interviewing.io/'},
			{'title': 'Crafting a compelling resume', 'url': 'https://www.linkedin.com/pulse/resume-tips/'},
		],
		'study': [
			{'title': 'Spaced repetition explained', 'url': 'https://www.gwern.net/Spaced-repetition'},
			{'title': 'Pomodoro technique basics', 'url': 'https://todoist.com/productivity-methods/pomodoro-technique'},
		],
	};

	List<Map<String, String>> recommendForText(String text) {
		final lower = text.toLowerCase();
		if (lower.contains('gym') || lower.contains('run') || lower.contains('fitness')) return _catalog['fitness']!;
		if (lower.contains('job') || lower.contains('interview') || lower.contains('career')) return _catalog['career']!;
		if (lower.contains('study') || lower.contains('exam') || lower.contains('learn')) return _catalog['study']!;
		return _catalog.values.expand((x) => x).take(2).toList();
	}
}


