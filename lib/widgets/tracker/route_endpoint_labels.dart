import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/route_location_helper.dart';

/// Displays start and end location names for a route, resolving via geocoding when needed.
class RouteEndpointLabels extends StatefulWidget {
  const RouteEndpointLabels({
    super.key,
    required this.start,
    required this.end,
    this.startName,
    this.endName,
    this.compact = false,
  });

  final LatLng start;
  final LatLng end;
  final String? startName;
  final String? endName;
  final bool compact;

  @override
  State<RouteEndpointLabels> createState() => _RouteEndpointLabelsState();
}

class _RouteEndpointLabelsState extends State<RouteEndpointLabels> {
  late Future<({String start, String end})> _labelsFuture;

  @override
  void initState() {
    super.initState();
    _labelsFuture = _loadLabels();
  }

  @override
  void didUpdateWidget(RouteEndpointLabels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start ||
        oldWidget.end != widget.end ||
        oldWidget.startName != widget.startName ||
        oldWidget.endName != widget.endName) {
      _labelsFuture = _loadLabels();
    }
  }

  Future<({String start, String end})> _loadLabels() {
    return RouteLocationHelper.resolveEndpointLabels(
      start: widget.start,
      end: widget.end,
      startName: widget.startName,
      endName: widget.endName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String start, String end})>(
      future: _labelsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        final labels = snapshot.data;
        if (labels == null) return const SizedBox.shrink();

        return widget.compact ? _buildCompact(labels.start, labels.end) : _buildExpanded(labels.start, labels.end);
      },
    );
  }

  Widget _buildLoading() {
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 8),
        Text('Loading locations...', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
      ],
    );
  }

  Widget _buildCompact(String startLabel, String endLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _endpointRow(icon: Icons.trip_origin, color: const Color(0xFF4CAF50), label: 'Start', value: startLabel),
        const SizedBox(height: 6),
        _endpointRow(icon: Icons.location_on, color: const Color(0xFFE53935), label: 'End', value: endLabel),
      ],
    );
  }

  Widget _buildExpanded(String startLabel, String endLabel) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _endpointRow(icon: Icons.trip_origin, color: const Color(0xFF4CAF50), label: 'Start', value: startLabel, expanded: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Container(width: 2, height: 18, color: AppColors.primaryGray.withValues(alpha: 0.25)),
              ],
            ),
          ),
          _endpointRow(icon: Icons.location_on, color: const Color(0xFFE53935), label: 'End', value: endLabel, expanded: true),
        ],
      ),
    );
  }

  Widget _endpointRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    bool expanded = false,
  }) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    return expanded ? content : content;
  }
}
