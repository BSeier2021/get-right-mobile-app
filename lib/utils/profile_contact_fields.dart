/// Parses address, phone, email, and social links from profile API `user` + `profile`.
Map<String, dynamic> extractProfileContactFields({required Map<String, dynamic> profile, required Map<String, dynamic> user}) {
  final phone = _firstNonEmpty([
    _nonEmptyString(profile['phoneNumber']),
    _nonEmptyString(profile['phone_number']),
    _nonEmptyString(profile['phone']),
    _nonEmptyString(profile['contactNumber']),
    _nonEmptyString(profile['contact_number']),
    _nonEmptyString(user['phoneNumber']),
    _nonEmptyString(user['phone']),
  ]);
  final email = _firstNonEmpty([_nonEmptyString(user['email']), _nonEmptyString(profile['email'])]);
  final address = _formatAddressFromProfile(profile);
  final socialAccounts = _parseSocialAccounts(profile, user);

  return {
    if (phone != null) 'phoneNumber': phone,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (address != null) ...{'address': address, 'location': address},
    if (socialAccounts.isNotEmpty) 'socialAccounts': socialAccounts,
  };
}

String? nonEmptyProfileString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

String? _nonEmptyString(dynamic value) => nonEmptyProfileString(value);

String? _firstNonEmpty(Iterable<String?> values) {
  for (final v in values) {
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

Map<String, dynamic> _asStringKeyedMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

String? _formatAddressMap(Map<String, dynamic> address) {
  final line1 = _firstNonEmpty([
    _nonEmptyString(address['streetAddress']),
    _nonEmptyString(address['street']),
    _nonEmptyString(address['addressLine1']),
    _nonEmptyString(address['address_line1']),
    _nonEmptyString(address['line1']),
  ]);
  final line2 = _firstNonEmpty([_nonEmptyString(address['addressLine2']), _nonEmptyString(address['address_line2']), _nonEmptyString(address['line2'])]);
  final cityStateZip = [
    _nonEmptyString(address['city']),
    _nonEmptyString(address['state'] ?? address['province']),
    _nonEmptyString(address['zipCode'] ?? address['zip'] ?? address['postalCode'] ?? address['postal_code']),
  ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
  final country = _nonEmptyString(address['country']);
  final parts = <String>[if (line1 != null) line1, if (line2 != null) line2, if (cityStateZip.isNotEmpty) cityStateZip, if (country != null) country];
  if (parts.isEmpty) return null;
  return parts.join('\n');
}

String? _formatAddressFromProfile(Map<String, dynamic> profile) {
  final direct = _firstNonEmpty([
    _nonEmptyString(profile['address']),
    _nonEmptyString(profile['location']),
    _nonEmptyString(profile['trainingLocation']),
    _nonEmptyString(profile['training_location']),
    _nonEmptyString(profile['fullAddress']),
    _nonEmptyString(profile['full_address']),
  ]);
  if (direct != null) return direct;

  final nested = profile['address'];
  if (nested is Map) return _formatAddressMap(_asStringKeyedMap(nested));

  return _formatAddressMap(profile);
}

String _normalizeSocialUrl(String platform, String raw) {
  var value = raw.trim();
  if (value.isEmpty) return value;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;

  final handle = value.startsWith('@') ? value.substring(1) : value;
  switch (platform) {
    case 'instagram':
      return 'https://instagram.com/$handle';
    case 'facebook':
      return 'https://facebook.com/$handle';
    case 'twitter':
    case 'x':
      return 'https://x.com/$handle';
    case 'tiktok':
      return handle.startsWith('@') ? 'https://tiktok.com/$handle' : 'https://tiktok.com/@$handle';
    case 'linkedin':
      return handle.contains('linkedin.com') ? 'https://$handle' : 'https://linkedin.com/in/$handle';
    case 'youtube':
      return handle.contains('youtube.com') || handle.contains('youtu.be') ? 'https://$handle' : 'https://youtube.com/@$handle';
    default:
      return value.contains('.') ? 'https://$value' : value;
  }
}

Map<String, String> _parseSocialAccounts(Map<String, dynamic> profile, Map<String, dynamic> user) {
  final accounts = <String, String>{};

  void add(String platform, String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final key = platform.toLowerCase().trim();
    if (key.isEmpty) return;
    accounts[key] = _normalizeSocialUrl(key, trimmed);
  }

  for (final containerKey in ['socialAccounts', 'socialMedia', 'socialLinks', 'social']) {
    final container = profile[containerKey] ?? user[containerKey];
    if (container is Map) {
      for (final entry in _asStringKeyedMap(container).entries) {
        add(entry.key, _nonEmptyString(entry.value));
      }
    } else if (container is List) {
      for (final item in container) {
        if (item is! Map) continue;
        final m = _asStringKeyedMap(item);
        final platform = _nonEmptyString(m['platform'] ?? m['type'] ?? m['name'] ?? m['label']);
        final url = _nonEmptyString(m['url'] ?? m['link'] ?? m['handle'] ?? m['value'] ?? m['username']);
        if (platform != null && url != null) add(platform, url);
      }
    }
  }

  for (final key in ['instagram', 'facebook', 'linkedin', 'twitter', 'x', 'tiktok', 'youtube', 'website', 'snapchat']) {
    add(key, _nonEmptyString(profile[key] ?? profile['${key}Url'] ?? profile['${key}_url']));
  }

  return accounts;
}

Map<String, String> socialAccountsFromContactFields(Map<String, dynamic> fields) {
  final raw = fields['socialAccounts'];
  if (raw is! Map) return const {};
  return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
}

bool hasSocialAccountsInContactFields(Map<String, dynamic> fields) => socialAccountsFromContactFields(fields).isNotEmpty;

String? addressFromContactFields(Map<String, dynamic> fields) => nonEmptyProfileString(fields['location'] ?? fields['address']);
