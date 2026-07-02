import 'package:flutter/material.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/utils/feed_post_mapper.dart' show coerceFeedApiBool;

/// True when API marks trainer certifications as admin-verified.
bool isCertificationsVerifiedFromApi(Map<String, dynamic>? node) {
  if (node == null || node.isEmpty) return false;
  for (final key in ['isCertificationsVerified', 'isCertified', 'is_certified', 'certified']) {
    if (coerceFeedApiBool(node[key])) return true;
  }
  return false;
}

bool isCertificationsVerifiedFromApiNodes(Iterable<dynamic> nodes) {
  for (final node in nodes) {
    if (node is Map && isCertificationsVerifiedFromApi(Map<String, dynamic>.from(node))) {
      return true;
    }
  }
  return false;
}

/// Program / bundle payloads may expose verification on the document or nested trainer.
bool isCertificationsVerifiedFromProgramApi(Map<String, dynamic> p) {
  final nodes = <dynamic>[p];
  final trainer = p['trainer'];
  if (trainer is Map) {
    nodes.add(trainer);
    final prof = trainer['profile'];
    if (prof is Map) nodes.add(prof);
  }
  return isCertificationsVerifiedFromApiNodes(nodes);
}

bool isCertificationsVerifiedFromBundleApi(Map<String, dynamic> b) {
  final nodes = <dynamic>[b];
  final trainer = b['trainer'];
  if (trainer is Map) {
    nodes.add(trainer);
    final prof = trainer['profile'];
    if (prof is Map) nodes.add(prof);
  }
  return isCertificationsVerifiedFromApiNodes(nodes);
}

/// Feed creator: user root + nested profile.
bool isCertificationsVerifiedFromCreatorApi(Map<String, dynamic> creator, Map<String, dynamic> profile) {
  return isCertificationsVerifiedFromApiNodes([creator, profile]);
}

/// Reads normalized UI maps (feed post, program card, trainer stub, etc.).
bool isCertifiedFromUiMap(Map<String, dynamic> m) =>
    m['isCertificationsVerified'] == true ||
    m['certified'] == true ||
    m['isCertified'] == true ||
    m['isTrainerCertified'] == true;

void applyCertifiedFields(Map<String, dynamic> target, {required bool verified}) {
  target['isCertificationsVerified'] = verified;
  target['certified'] = verified;
  target['isCertified'] = verified;
}

/// Feed reels/grid: trainer role plus admin-verified certifications.
bool showFeedCreatorVerifiedBadge(Map<String, dynamic> post) {
  if (post['isTrainer'] != true) return false;
  return isCertifiedFromUiMap(post);
}

Widget verifiedBadgeIcon({double size = 16, Color? color}) {
  return Icon(Icons.verified, size: size, color: color ?? AppColors.completed);
}

/// Small badge for profile avatar corner (Instagram-style verified mark).
Widget verifiedAvatarBadge({double size = 22}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 4, offset: const Offset(0, 1))],
    ),
    alignment: Alignment.center,
    child: Icon(Icons.verified, size: size - 5, color: AppColors.completed),
  );
}

/// Profile header chip shown under the trainer name.
Widget verifiedTrainerChip() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.completed.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.completed.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, size: 14, color: AppColors.completed),
        const SizedBox(width: 5),
        Text(
          'Verified Trainer',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.completed, height: 1.1),
        ),
      ],
    ),
  );
}
