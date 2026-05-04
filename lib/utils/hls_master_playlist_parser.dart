import 'dart:convert';

import 'package:get_right/models/hls_video_quality.dart';
import 'package:http/http.dart' as http;

/// Parses HLS **master** playlists (`#EXT-X-STREAM-INF` + variant URI).
///
/// Relative variant lines (e.g. `1080p/playlist.m3u8`) are resolved with [Uri.resolve].
class HlsMasterPlaylistParser {
  HlsMasterPlaylistParser._();

  static final RegExp _resolutionRe = RegExp(r'RESOLUTION=(\d+)x(\d+)', caseSensitive: false);
  static final RegExp _bandwidthRe = RegExp(r'BANDWIDTH=(\d+)', caseSensitive: false);

  /// Fetches [masterUri] and returns variant qualities (no "Auto" row).
  static Future<List<HlsVideoQuality>> fetchVariantQualities(Uri masterUri) async {
    final res = await http.get(masterUri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Playlist HTTP ${res.statusCode}');
    }
    final text = utf8.decode(res.bodyBytes);
    return parseVariantQualities(masterUri, text);
  }

  static bool isMasterPlaylistText(String body) => body.contains('#EXT-X-STREAM-INF');

  /// Parses variant streams from playlist text.
  static List<HlsVideoQuality> parseVariantQualities(Uri masterUri, String body) {
    if (!isMasterPlaylistText(body)) {
      return [];
    }

    final lines = const LineSplitter().convert(body);
    final out = <HlsVideoQuality>[];
    String? pendingInf;

    void flushPending(String uriLine) {
      if (pendingInf == null) return;
      if (uriLine.startsWith('#')) return;

      final variantUri = masterUri.resolve(uriLine.trim());
      final height = _parseHeight(pendingInf!);
      final bw = _parseBandwidth(pendingInf!);

      final label = height != null ? '${height}p' : (bw != null ? '${(bw / 1000).round()} kbps' : 'Alternate stream');

      out.add(
        HlsVideoQuality(
          id: variantUri.toString(),
          label: label,
          playbackUri: variantUri,
          isAdaptive: false,
          heightPx: height,
          bandwidth: bw,
        ),
      );
      pendingInf = null;
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXT-X-STREAM-INF')) {
        pendingInf = line;
        continue;
      }

      if (pendingInf != null && !line.startsWith('#')) {
        flushPending(line);
      }
    }

    out.sort((a, b) => (b.heightPx ?? 0).compareTo(a.heightPx ?? 0));
    final seen = <String>{};
    return out.where((q) => seen.add(q.playbackUri.toString())).toList();
  }

  static int? _parseHeight(String infLine) {
    final m = _resolutionRe.firstMatch(infLine);
    if (m == null) return null;
    return int.tryParse(m.group(2) ?? '');
  }

  static int? _parseBandwidth(String infLine) {
    final m = _bandwidthRe.firstMatch(infLine);
    if (m == null) return null;
    return int.tryParse(m.group(1) ?? '');
  }
}
