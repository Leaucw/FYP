enum AchievementCategory {
  academic,
  career,
  travel,
  health,
  personalGrowth,
  relationship,
  other,
}

class AchievementConfig {
  // ⭐ Monthly points cap
  static const int monthlyCap = 300;

  // ⭐ Base scoring rules
  static int basePoints(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.academic:
        return 20;
      case AchievementCategory.career:
        return 25;
      case AchievementCategory.health:
        return 15;
      case AchievementCategory.travel:
        return 10;
      case AchievementCategory.personalGrowth:
        return 15;
      case AchievementCategory.relationship:
        return 10;
      case AchievementCategory.other:
        return 10;
    }
  }

  // ⭐ Convert enum → string (for Firestore)
  static String categoryToString(AchievementCategory c) {
    return c.toString().split('.').last;
  }

  // ⭐ Convert string → enum (for loading from Firestore)
  static AchievementCategory categoryFromString(String value) {
    return AchievementCategory.values.firstWhere(
          (c) => c.toString().split('.').last == value,
      orElse: () => AchievementCategory.other,
    );
  }

  // ⭐ NEW: Badge leveling system
  static String badgeFor(int totalPoints) {
    if (totalPoints >= 10000) return "Gold";
    if (totalPoints >= 5000) return "Silver";
    return "Bronze";
  }
}
