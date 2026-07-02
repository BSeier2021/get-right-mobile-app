import 'package:get_right/models/user_preference_option.dart';

/// Parsed `GET /customer/profile` → `data.user` (+ nested `profile`).
class CustomerProfileDto {
  final String userId;
  final String email;
  final bool isVerified;
  final bool isProfileCompleted;
  final String? fullName;
  final String? gender;
  final String? phoneNumber;
  /// Body weight in kg when returned by profile APIs.
  final double? weight;
  /// `YYYY-MM-DD` when parsable from API ISO string.
  final String? dateofbirth;
  final String? profilePictureUrl;
  final String? bio;
  final String? primaryFocus;
  /// Human-readable name from nested `profile.preferences` when API returns an object.
  final String? preferencesName;
  final String? preferencesDescription;
  final List<String> mainGoals;
  /// Display string (e.g. `title` from nested `profile.fitnessLevel`).
  final String? fitnessLevel;
  /// Display string (e.g. `title` from nested `profile.exerciseFrequency`).
  final String? exerciseFrequency;

  const CustomerProfileDto({
    required this.userId,
    required this.email,
    required this.isVerified,
    required this.isProfileCompleted,
    this.fullName,
    this.gender,
    this.phoneNumber,
    this.weight,
    this.dateofbirth,
    this.profilePictureUrl,
    this.bio,
    this.primaryFocus,
    this.preferencesName,
    this.preferencesDescription,
    this.mainGoals = const [],
    this.fitnessLevel,
    this.exerciseFrequency,
  });

  static String? _profilePictureUrlFrom(Map<String, dynamic>? p) {
    if (p == null) return null;
    final raw = p['profilePicture'];
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final u = m['url']?.toString().trim();
      return (u != null && u.isNotEmpty) ? u : null;
    }
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  static String? _normalizeDob(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
      return s.substring(0, 10);
    }
    return s;
  }

  static double? _parseWeight(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      final parsed = v.toDouble();
      return parsed > 0 ? parsed : null;
    }
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final parsed = double.tryParse(s);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  /// Nested `{ title, value, name }` or plain string (API variants).
  static String? _displayFromNestedOrString(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      for (final key in ['title', 'name', 'value', 'label']) {
        final s = m[key]?.toString().trim();
        if (s != null && s.isNotEmpty) return s;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _asStringKeyedMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static Map<String, dynamic>? _preferencesMap(Map<String, dynamic> p) {
    final raw = p['preferences'] ?? p['preference'];
    return _asStringKeyedMap(raw);
  }

  static bool _isMissing(dynamic v) {
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is List) return v.isEmpty;
    return false;
  }

  static List<String> _mainGoalsFrom(Map<String, dynamic> p) {
    final rawMain = p['mainGoals'] ?? p['main_goals'];
    if (rawMain is List && rawMain.isNotEmpty) {
      return rawMain.map((e) {
        if (e is String) {
          final s = e.trim();
          return s.isEmpty ? null : s;
        }
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final v = m['value']?.toString().trim();
          if (v != null && v.isNotEmpty) return v;
          final slug = m['slug']?.toString().trim();
          if (slug != null && slug.isNotEmpty) return slug;
          final n = m['name']?.toString().trim();
          if (n != null && n.isNotEmpty) return n;
        }
        return null;
      }).whereType<String>().toList();
    }

    final rawGoals = p['goals'] ?? p['userGoals'];
    if (rawGoals is! List || rawGoals.isEmpty) return const [];
    return rawGoals.map((e) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final v = m['value']?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
        final n = m['name']?.toString().trim();
        if (n != null && n.isNotEmpty) return n;
      }
      if (e is String) {
        final s = e.trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }).where((s) => s.isNotEmpty).toList();
  }

  /// Merges `user.profile`, optional sibling `data.profile`, and onboarding fields that some APIs put on `user` root.
  static Map<String, dynamic> _mergedProfileMap(Map<String, dynamic> data, Map<String, dynamic> user) {
    final merged = <String, dynamic>{};
    final nested = _asStringKeyedMap(user['profile']);
    if (nested != null) merged.addAll(nested);
    final dataProfile = _asStringKeyedMap(data['profile']);
    if (dataProfile != null) {
      for (final e in dataProfile.entries) {
        if (!merged.containsKey(e.key) || _isMissing(merged[e.key])) merged[e.key] = e.value;
      }
    }
    void copyUserField(List<String> keys, String intoKey) {
      if (!_isMissing(merged[intoKey])) return;
      for (final k in keys) {
        final v = user[k];
        if (!_isMissing(v)) {
          merged[intoKey] = v;
          return;
        }
      }
    }

    copyUserField(const ['primaryFocus', 'primary_focus'], 'primaryFocus');
    copyUserField(const ['mainGoals', 'main_goals'], 'mainGoals');
    copyUserField(const ['goals', 'userGoals'], 'goals');
    copyUserField(const ['fitnessLevel', 'fitness_level'], 'fitnessLevel');
    copyUserField(const ['exerciseFrequency', 'exercise_frequency', 'exercisePlan', 'exercise_plan'], 'exerciseFrequency');
    copyUserField(const ['preferences', 'preference'], 'preferences');
    copyUserField(const ['fullName', 'full_name'], 'fullName');
    copyUserField(const ['phoneNumber', 'phone_number'], 'phoneNumber');
    copyUserField(const ['gender'], 'gender');
    copyUserField(const ['bio'], 'bio');
    copyUserField(const ['dateofbirth', 'date_of_birth'], 'dateofbirth');
    copyUserField(const ['weight'], 'weight');
    return merged;
  }

  static bool _isSuccessfulPayload(Map<String, dynamic> root) {
    final s = root['success'];
    if (s == true || s == 1) return true;
    if (s is String && s.toLowerCase() == 'true') return true;
    final st = root['status'];
    if (st == 200 || st == '200') return true;
    return false;
  }

  /// Builds from login / auto-login `data` object (`data.user`, `data.user.profile`, …).
  static CustomerProfileDto? fromLoginData(Map<String, dynamic> data) {
    return tryParse(<String, dynamic>{'success': true, 'data': data});
  }

  /// Returns null if [response] is not a successful profile payload.
  static CustomerProfileDto? tryParse(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);
    if (!_isSuccessfulPayload(root)) return null;
    final dataRaw = root['data'];
    if (dataRaw is! Map) return null;
    final data = Map<String, dynamic>.from(dataRaw);

    Map<String, dynamic> user;
    final userRaw = data['user'];
    if (userRaw is Map) {
      user = Map<String, dynamic>.from(userRaw);
    } else if (data['_id'] != null || data['email'] != null) {
      user = Map<String, dynamic>.from(data);
    } else {
      return null;
    }

    final profile = _mergedProfileMap(data, user);

    bool flag(dynamic v, {bool defaultValue = false}) {
      if (v == true) return true;
      if (v == false) return false;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == 'true' || s == '1') return true;
        if (s == 'false' || s == '0') return false;
      }
      return defaultValue;
    }

    final uid = user['_id']?.toString() ?? '';
    if (uid.isEmpty) return null;

    final prefMap = _preferencesMap(profile);

    String? primaryFocusStr = profile['primaryFocus']?.toString() ?? profile['primary_focus']?.toString();
    primaryFocusStr = primaryFocusStr?.trim();
    if (primaryFocusStr != null && primaryFocusStr.isEmpty) primaryFocusStr = null;
    // Backend often returns only `profile.preferences` as an object (no top-level primaryFocus string).
    if (primaryFocusStr == null && prefMap != null && prefMap.isNotEmpty) {
      primaryFocusStr = UserPreferenceOption.fromJson(prefMap).value;
    }

    return CustomerProfileDto(
      userId: uid,
      email: user['email']?.toString() ?? '',
      isVerified: flag(user['isVerified'], defaultValue: false) || flag(user['is_verified'], defaultValue: false),
      isProfileCompleted: flag(user['isProfileCompleted'], defaultValue: false) || flag(user['is_profile_completed'], defaultValue: false),
      fullName: profile['fullName']?.toString() ?? profile['full_name']?.toString(),
      gender: profile['gender']?.toString(),
      phoneNumber: profile['phoneNumber']?.toString() ?? profile['phone_number']?.toString(),
      weight: _parseWeight(profile['weight']),
      dateofbirth: _normalizeDob(profile['dateofbirth'] ?? profile['date_of_birth']),
      profilePictureUrl: _profilePictureUrlFrom(profile),
      bio: profile['bio']?.toString(),
      primaryFocus: primaryFocusStr,
      preferencesName: prefMap?['name']?.toString().trim(),
      preferencesDescription: prefMap?['description']?.toString().trim(),
      mainGoals: _mainGoalsFrom(profile),
      fitnessLevel: _displayFromNestedOrString(profile['fitnessLevel'] ?? profile['fitness_level']),
      exerciseFrequency: _displayFromNestedOrString(
        profile['exerciseFrequency'] ?? profile['exercise_frequency'] ?? profile['exercisePlan'] ?? profile['exercise_plan'],
      ),
    );
  }
}
