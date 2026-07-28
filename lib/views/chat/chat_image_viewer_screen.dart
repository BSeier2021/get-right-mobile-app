import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_right/widgets/safe_network_image.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

class ChatImageViewerScreen extends StatefulWidget {
  const ChatImageViewerScreen({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
    this.title,
  });

  final List<ChatAttachment> attachments;
  final int initialIndex;
  final String? title;

  @override
  State<ChatImageViewerScreen> createState() => _ChatImageViewerScreenState();
}

class _ChatImageViewerScreenState extends State<ChatImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.attachments.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? _resolvedUrl(ChatAttachment attachment) {
    if (attachment.isLocal) return attachment.url;
    return ImageUrlSanitizer.resolveMediaUrl(attachment.url) ?? ImageUrlSanitizer.asHttpUrlOrNull(attachment.url);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.attachments.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          count > 1 ? '${_currentIndex + 1} / $count' : (widget.title ?? 'Photo'),
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: count,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) => _ImagePage(attachment: widget.attachments[index], resolvedUrl: _resolvedUrl(widget.attachments[index])),
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.attachment, required this.resolvedUrl});

  final ChatAttachment attachment;
  final String? resolvedUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (attachment.isLocal) {
      final file = File(attachment.url);
      if (!file.existsSync()) {
        return _errorPlaceholder('Image file not found');
      }
      return Image.file(file, fit: BoxFit.contain);
    }

    final url = resolvedUrl;
    if (url == null || url.isEmpty) {
      return _errorPlaceholder('Invalid image URL');
    }

    return SafeNetworkImage(
      url: url,
      fit: BoxFit.contain,
      fallback: _errorPlaceholder('Failed to load image'),
    );
  }

  Widget _errorPlaceholder(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
