import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get_right/models/gr_cardio_entry.dart';

/// Loads and queries the bundled Get Right cardio catalog (`CardioList.json`).
class GrCardioCatalog {
  GrCardioCatalog._();

  static final GrCardioCatalog instance = GrCardioCatalog._();

  bool _loaded = false;
  List<GrCardioEntry> _entries = const [];

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString('assets/gr_json/CardioList.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('CardioList.json must be a JSON object');
    }

    final list = decoded['cardioList'];
    if (list is! List) {
      throw StateError('CardioList.json is missing cardioList');
    }

    final parsed = <GrCardioEntry>[];
    for (final item in list) {
      if (item is! Map) continue;
      final entry = GrCardioEntry.fromJson(Map<String, dynamic>.from(item));
      if (entry.id.isEmpty || entry.name.isEmpty) continue;
      parsed.add(entry);
    }

    _entries = parsed;
    _loaded = true;
  }

  List<GrCardioEntry> get all => List.unmodifiable(_entries);

  List<GrCardioEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return _entries.where((e) {
      if (e.name.toLowerCase().contains(q)) return true;
      if (e.description.toLowerCase().contains(q)) return true;
      if (e.metrics.any((m) => m.toLowerCase().contains(q))) return true;
      if (e.tags.any((t) => t.contains(q))) return true;
      return false;
    }).toList(growable: false);
  }

  List<GrCardioEntry> filterByTags(Set<String> tags) {
    if (tags.isEmpty) return all;
    final normalized = tags.map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toSet();
    return _entries.where((e) => e.tags.any(normalized.contains)).toList(growable: false);
  }

  Set<String> get availableTags {
    final tags = <String>{};
    for (final entry in _entries) {
      tags.addAll(entry.tags);
    }
    return tags;
  }
}
