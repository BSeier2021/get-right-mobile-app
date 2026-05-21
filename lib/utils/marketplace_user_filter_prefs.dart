import 'package:get_right/models/exercise_category_option.dart';
import 'package:get_right/utils/customer_profile_enums.dart';

/// Maps onboarding / profile answers to marketplace program filter defaults.
abstract final class MarketplaceUserFilterPrefs {
  static const Set<String> difficultyValues = {'Beginner', 'Intermediate', 'Advanced', 'Professional'};

  /// API `difficulties` enum value from stored fitness level or profile title.
  static String? difficultyFromFitnessLevel(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    for (final d in difficultyValues) {
      if (d.toLowerCase() == s.toLowerCase()) return d;
    }
    final lower = s.toLowerCase();
    if (lower.contains('begin')) return 'Beginner';
    if (lower.contains('inter')) return 'Intermediate';
    if (lower.contains('advanc')) return 'Advanced';
    if (lower.contains('pro') || lower.contains('elite')) return 'Professional';
    return null;
  }

  /// Picks exercise-category ids that best match quiz preference + goals.
  static Set<String> categoryIdsFromUserContext({
    required List<ExerciseCategoryOption> categories,
    String? preferenceName,
    String? primaryFocusSlug,
    List<String> goalNames = const [],
  }) {
    if (categories.isEmpty) return {};

    final slug = CustomerProfileEnums.normalizePrimaryFocus(primaryFocusSlug) ??
        CustomerProfileEnums.primaryFocusFromDisplayName(preferenceName);
    final keywords = <String>{};
    if (slug != null) {
      keywords.addAll(_keywordsForPrimaryFocus(slug));
    }
    for (final g in goalNames) {
      keywords.addAll(_keywordsForGoal(g));
    }
    if (keywords.isEmpty && preferenceName != null && preferenceName.trim().isNotEmpty) {
      keywords.add(preferenceName.trim().toLowerCase());
    }

    final matched = <String>{};
    for (final c in categories) {
      if (c.id.isEmpty || c.name.isEmpty) continue;
      final name = c.name.toLowerCase();
      for (final kw in keywords) {
        if (name.contains(kw) || kw.contains(name)) {
          matched.add(c.id);
          break;
        }
      }
    }
    return matched;
  }

  static Iterable<String> _keywordsForPrimaryFocus(String slug) {
    switch (slug) {
      case 'strength_training':
        return const ['strength', 'hypertrophy', 'muscle', 'chest', 'back', 'bodyweight', 'power'];
      case 'running_cardio':
        return const ['cardio', 'running', 'hiit', 'endurance'];
      case 'flexibility':
        return const ['flexibility', 'mobility', 'stretch', 'yoga'];
      case 'weight_loss':
        return const ['fat', 'loss', 'weight', 'cardio'];
      case 'general_fitness':
        return const ['general', 'fitness', 'core', 'full'];
      default:
        return const [];
    }
  }

  static Iterable<String> _keywordsForGoal(String goal) {
    final slug = CustomerProfileEnums.normalizeMainGoal(goal) ?? CustomerProfileEnums.mainGoalFromDisplayName(goal);
    switch (slug) {
      case 'lose_weight':
        return const ['fat', 'loss', 'cardio', 'weight'];
      case 'build_muscle':
        return const ['strength', 'hypertrophy', 'muscle'];
      case 'improve_performance':
        return const ['sport', 'performance', 'athletic'];
      case 'stay_healthy':
        return const ['general', 'wellness', 'core'];
      case 'track_progress':
        return const ['strength', 'general'];
      case 'build_habits':
        return const ['general', 'bodyweight'];
      default:
        if (goal.trim().isNotEmpty) return [goal.trim().toLowerCase()];
        return const [];
    }
  }
}
