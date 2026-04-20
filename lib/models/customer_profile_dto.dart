/// Parsed `GET /customer/profile` → `data.user` (+ nested `profile`).
class CustomerProfileDto {
  final String userId;
  final String email;
  final bool isVerified;
  final bool isProfileCompleted;
  final String? fullName;
  final String? gender;
  final String? phoneNumber;
  /// `YYYY-MM-DD` when parsable from API ISO string.
  final String? dateofbirth;
  final String? profilePictureUrl;
  final String? bio;
  final String? primaryFocus;
  final List<String> mainGoals;
  final String? fitnessLevel;
  final String? exerciseFrequency;

  const CustomerProfileDto({
    required this.userId,
    required this.email,
    required this.isVerified,
    required this.isProfileCompleted,
    this.fullName,
    this.gender,
    this.phoneNumber,
    this.dateofbirth,
    this.profilePictureUrl,
    this.bio,
    this.primaryFocus,
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

  static List<String> _stringListField(Map<String, dynamic>? p, String key) {
    if (p == null) return const [];
    final raw = p[key];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
  }

  static List<String> _mainGoalsFrom(Map<String, dynamic>? p) {
    final fromMain = _stringListField(p, 'mainGoals');
    if (fromMain.isNotEmpty) return fromMain;
    return _stringListField(p, 'goals');
  }

  /// Returns null if [response] is not a successful profile payload.
  static CustomerProfileDto? tryParse(dynamic response) {
    if (response is! Map<String, dynamic>) return null;
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    final user = data['user'];
    if (user is! Map<String, dynamic>) return null;

    Map<String, dynamic>? profile;
    final pr = user['profile'];
    if (pr is Map<String, dynamic>) {
      profile = pr;
    } else if (pr is Map) {
      profile = Map<String, dynamic>.from(pr);
    }

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

    return CustomerProfileDto(
      userId: uid,
      email: user['email']?.toString() ?? '',
      isVerified: flag(user['isVerified'], defaultValue: false) || flag(user['is_verified'], defaultValue: false),
      isProfileCompleted: flag(user['isProfileCompleted'], defaultValue: false) || flag(user['is_profile_completed'], defaultValue: false),
      fullName: profile?['fullName']?.toString(),
      gender: profile?['gender']?.toString(),
      phoneNumber: profile?['phoneNumber']?.toString(),
      dateofbirth: _normalizeDob(profile?['dateofbirth']),
      profilePictureUrl: _profilePictureUrlFrom(profile),
      bio: profile?['bio']?.toString(),
      primaryFocus: profile?['primaryFocus']?.toString(),
      mainGoals: _mainGoalsFrom(profile),
      fitnessLevel: profile?['fitnessLevel']?.toString(),
      exerciseFrequency: profile?['exerciseFrequency']?.toString(),
    );
  }
}
