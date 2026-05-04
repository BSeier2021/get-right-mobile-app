/// One selectable quality row (HLS master "Auto" or a variant playlist).
class HlsVideoQuality {
  const HlsVideoQuality({
    required this.id,
    required this.label,
    required this.playbackUri,
    required this.isAdaptive,
    this.heightPx,
    this.bandwidth,
  });

  /// Native ABR using the full master `.m3u8` URL.
  factory HlsVideoQuality.auto(Uri masterUri) {
    return HlsVideoQuality(
      id: 'auto',
      label: 'Auto',
      playbackUri: masterUri,
      isAdaptive: true,
      heightPx: null,
      bandwidth: null,
    );
  }

  final String id;
  final String label;
  final Uri playbackUri;
  final bool isAdaptive;
  final int? heightPx;
  final int? bandwidth;

  @override
  bool operator ==(Object other) => other is HlsVideoQuality && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
