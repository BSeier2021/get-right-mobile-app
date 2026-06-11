import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:get_right/services/chat_audio_player_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/controllers/chat_controller.dart';
import 'package:get_right/models/chat_message_model.dart';
import 'package:get_right/models/report_block_model.dart';
import 'package:get_right/models/enrolled_program_model.dart';
import 'package:get_right/services/api_service.dart';
import 'package:get_right/services/chat_socket_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/chat_message_bubble.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

class _PendingMedia {
  const _PendingMedia({required this.path, required this.type, required this.name});

  final String path;
  final String type;
  final String name;
}

void _showChatPhotoLimitSnackbar({int? selectedCount}) {
  final limit = AppConstants.maxChatImageAttachments;
  final message = selectedCount != null && selectedCount > limit
      ? 'You selected $selectedCount photos. You can send up to $limit photos at a time.'
      : 'You can send up to $limit photos at a time.';
  Get.snackbar('Photo limit', message, snackPosition: SnackPosition.BOTTOM);
}

List<XFile> _limitPickedChatImages(List<XFile> images) {
  final limit = AppConstants.maxChatImageAttachments;
  if (images.length <= limit) return images;
  _showChatPhotoLimitSnackbar(selectedCount: images.length);
  return images.take(limit).toList();
}

/// Chat Room Screen - Full chat interface with trainer
class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _isRecorderInitialized = false;

  ChatController? _chatController;
  StreamSubscription<Map<String, dynamic>>? _conversationUpdatedSub;
  String? _conversationId;
  String? _trainerId;
  String? _trainerName;
  String? _programId;
  String? _programTitle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onMessagesScroll);
    _initializeController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatController?.resumeActiveConversation();
      _chatController?.refreshConversationBlockStatus();
    }
  }

  void _onMessagesScroll() {
    if (!_scrollController.hasClients || _chatController == null) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _chatController!.loadMoreMessages();
    }
  }

  Future<FlutterSoundRecorder> _recorder() async {
    _audioRecorder ??= FlutterSoundRecorder();
    if (!_isRecorderInitialized) {
      await _audioRecorder!.openRecorder();
      _isRecorderInitialized = true;
    }
    return _audioRecorder!;
  }

  Future<void> _initializeController() async {
    try {
      final apiService = await ApiService.getInstance();
      final storageService = await StorageService.getInstance();

      // Check if controller already exists
      if (Get.isRegistered<ChatController>()) {
        _chatController = Get.find<ChatController>();
      } else {
        _chatController = Get.put(ChatController(apiService, storageService));
      }

      if (!mounted) return;
      setState(() {});
      _attachConversationUpdatedListener();
      await _loadChatData();
    } catch (e) {
      if (mounted) {
        Get.snackbar('Chat', e.toString().replaceFirst('Exception: ', ''), snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  Future<void> _loadChatData() async {
    final args = Get.arguments;
    if (args is Map) {
      final rawConversationId = args['conversationId']?.toString().trim();
      _conversationId = (rawConversationId != null && rawConversationId.isNotEmpty) ? rawConversationId : null;
      _trainerId = args['trainerId']?.toString().trim();
      _trainerName = args['trainerName']?.toString();
      _programId = args['programId']?.toString().trim();
      _programTitle = args['programTitle']?.toString();

      if (_conversationId != null && _chatController != null) {
        await _chatController!.switchToConversation(_conversationId!, trainerId: _trainerId, programId: _programId);
      } else if (_trainerId != null && _programId != null) {
        await _startNewConversation();
      } else if (_trainerId != null && _trainerId!.isNotEmpty) {
        await _startConversationWithTrainer();
      }

      final initialMessage = args['initialMessage']?.toString().trim();
      if (initialMessage != null && initialMessage.isNotEmpty && _chatController != null) {
        await _chatController!.sendMessage(initialMessage);
      }
    } else if (args is EnrolledProgramModel) {
      final program = args;
      _trainerId = program.trainerId;
      _trainerName = program.trainerName;
      _programId = program.programId;
      _programTitle = program.programTitle;
      await _startNewConversation();
    }

    if (mounted) setState(() {});
  }

  Future<void> _startConversationWithTrainer() async {
    if (_trainerId == null || _chatController == null) return;

    final conversation = await _chatController!.startConversationWithUser(_trainerId!);
    if (conversation == null || _chatController == null) return;

    _conversationId = conversation.id;
    _trainerName ??= conversation.trainerName;
    _programId ??= conversation.programId.isNotEmpty ? conversation.programId : null;
    _programTitle ??= conversation.programTitle.isNotEmpty ? conversation.programTitle : null;
    await _chatController!.switchToConversation(conversation.id, trainerId: _trainerId, programId: _programId);
  }

  Future<void> _startNewConversation() async {
    if (_trainerId == null || _programId == null || _chatController == null) return;

    final conversationId = await _chatController!.startConversation(
      trainerId: _trainerId!,
      trainerName: _trainerName ?? 'Trainer',
      trainerImage: null,
      programId: _programId!,
      programTitle: _programTitle ?? 'Program',
    );

    if (conversationId != null && _chatController != null) {
      _conversationId = conversationId;
      await _chatController!.switchToConversation(conversationId, trainerId: _trainerId, programId: _programId);
    }
  }

  void _attachConversationUpdatedListener() {
    _conversationUpdatedSub?.cancel();
    _conversationUpdatedSub = ChatSocketService.instance.onConversationUpdated.listen((payload) {
      if (!mounted || _chatController == null) return;
      _chatController!.onConversationUpdated(payload);
    });
  }

  void _detachConversationUpdatedListener() {
    _conversationUpdatedSub?.cancel();
    _conversationUpdatedSub = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachConversationUpdatedListener();
    _chatController?.leaveChatRoom();
    _chatController?.stopTypingInRoom();
    _messageController.dispose();
    _scrollController.dispose();
    if (_isRecorderInitialized && _audioRecorder != null) {
      _audioRecorder!.closeRecorder();
      _audioRecorder = null;
    }
    _recordingTimer?.cancel();
    ChatAudioPlayerService.instance.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _chatController == null) return;

    _messageController.clear();
    await _chatController!.sendMessage(message);
    _scrollToBottom();
  }

  Future<void> _pickImages() async {
    if (_chatController == null) return;
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    final limited = _limitPickedChatImages(images);
    await _showMediaComposer(
      initialMedia: limited.map((image) => _PendingMedia(path: image.path, type: 'image', name: image.name)).toList(),
    );
  }

  Future<void> _pickVideo() async {
    if (_chatController == null) return;
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    await _showMediaComposer(
      initialMedia: [_PendingMedia(path: video.path, type: 'video', name: video.name)],
    );
  }

  Future<void> _showMediaComposer({required List<_PendingMedia> initialMedia}) async {
    if (_chatController == null || initialMedia.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _MediaComposerSheet(initialMedia: initialMedia, chatController: _chatController!, onSent: _scrollToBottom),
    );
  }

  Future<void> _pickAudioFile() async {
    if (_chatController == null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;

    await _chatController!.sendFileMessage(filePath: path, type: 'audio', fileName: result!.files.single.name);
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    try {
      // Check microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        Get.snackbar('Permission Denied', 'Microphone permission is required');
        return;
      }

      final recorder = await _recorder();
      final directory = await getApplicationDocumentsDirectory();
      _recordingPath = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      await recorder.startRecorder(toFile: _recordingPath, codec: Codec.aacADTS);

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording(bool send) async {
    _recordingTimer?.cancel();

    if (!_isRecording || _recordingPath == null || _audioRecorder == null) return;

    final path = _recordingPath!;

    try {
      await _audioRecorder!.stopRecorder();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingPath = null;
          _recordingDuration = 0;
        });
      }
      Get.snackbar('Error', 'Failed to stop recording: $e');
      return;
    }

    final recordedSeconds = _recordingDuration;

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingPath = null;
      _recordingDuration = 0;
    });

    final file = File(path);
    if (!await file.exists()) {
      if (send) {
        Get.snackbar('Audio', 'Recording file not found. Please try again.');
      }
      return;
    }

    final fileSize = await file.length();
    if (send && fileSize > 0 && _chatController != null) {
      await _chatController!.sendFileMessage(
        filePath: path,
        type: 'audio',
        fileName: 'audio_message.aac',
        durationSeconds: recordedSeconds > 0 ? recordedSeconds : 1,
      );
      _scrollToBottom();
    } else {
      try {
        await file.delete();
      } catch (_) {}
      if (send) {
        Get.snackbar('Audio', 'Recording was too short. Please try again.');
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.onSurface),
              title: Text('Photos', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              subtitle: Text('Select multiple images', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: AppColors.onSurface),
              title: Text('Video', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic, color: AppColors.onSurface),
              title: Text('Record voice', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _startRecording();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Delete message', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMessage(ChatMessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete message?', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
        content: Text('This message will be removed for everyone in the chat.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || _chatController == null || !mounted) return;
    await _chatController!.deleteMessage(message.id);
  }

  void _showReportBlockOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Obx(() {
        final isBlockedByMe = _chatController?.isBlockedByMe.value ?? false;

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag, color: AppColors.error),
                title: Text('Report', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog();
                },
              ),
              ListTile(
                leading: Icon(isBlockedByMe ? Icons.lock_open_outlined : Icons.block, color: isBlockedByMe ? AppColors.accent : AppColors.error),
                title: Text(isBlockedByMe ? 'Unblock' : 'Block', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                onTap: () {
                  Navigator.pop(context);
                  if (isBlockedByMe) {
                    _onUnblockUser();
                  } else {
                    _showBlockDialog();
                  }
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showReportDialog() {
    final descriptionController = TextEditingController();
    String? selectedReason;

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report Trainer', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
                    const SizedBox(height: 16),
                    Text('Reason:', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                    const SizedBox(height: 8),
                    ...ReportReasons.all.map(
                      (reason) => RadioListTile<String>(
                        title: Text(ReportReasons.getDisplayName(reason), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedReason = value;
                          });
                        },
                        activeColor: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Additional Details (Optional)',
                        labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.primaryGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.primaryGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.accent, width: 2),
                        ),
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: selectedReason == null
                              ? null
                              : () async {
                                  if (_trainerId != null && selectedReason != null && _chatController != null) {
                                    Get.back(); // Close dialog first
                                    await _chatController!.reportTrainer(
                                      trainerId: _trainerId!,
                                      reason: selectedReason!,
                                      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showBlockDialog() {
    bool isBlocking = false;
    // Capture the screen context before showing dialog
    final screenContext = context;

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Block Trainer?', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
                  const SizedBox(height: 16),
                  Text(
                    'You will no longer receive messages from this trainer. This action cannot be undone.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isBlocking ? null : () => Get.back(),
                        child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isBlocking
                            ? null
                            : () async {
                                if (_trainerId != null && _chatController != null) {
                                  setDialogState(() {
                                    isBlocking = true;
                                  });

                                  // Close dialog first to avoid snackbar conflict
                                  Navigator.of(dialogContext).pop();

                                  // Wait for dialog to close
                                  await Future.delayed(const Duration(milliseconds: 100));

                                  try {
                                    // Block the trainer (this will show a snackbar)
                                    await _chatController!.blockTrainer(_trainerId!);

                                    // Wait for snackbar to appear and settle
                                    await Future.delayed(const Duration(milliseconds: 800));

                                    // Navigate back from chat room using Navigator instead of Get.back()
                                    // to avoid snackbar disposal issues
                                    if (mounted) {
                                      try {
                                        if (Navigator.of(screenContext).canPop()) {
                                          Navigator.of(screenContext).pop();
                                        }
                                      } catch (e) {
                                        // Context might be invalid, try Get.back() as fallback
                                        try {
                                          Get.back();
                                        } catch (_) {
                                          // Ignore if navigation fails
                                        }
                                      }
                                    }
                                  } catch (e) {
                                    // Error is already shown by the controller
                                    // If we need to show error, we can do it here
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.onError),
                        child: isBlocking
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.onError)))
                            : const Text('Block'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _onUnblockUser() async {
    final userId = _chatController?.otherParticipant?.id ?? _trainerId;
    if (userId == null || userId.isEmpty || _chatController == null) return;

    try {
      await _chatController!.unblockTrainer(userId);
    } catch (_) {
      // Error snackbar is shown by the controller.
    }
  }

  Widget _buildChatBottomBar() {
    return Obx(() {
      final blockedByMe = _chatController!.isBlockedByMe.value;
      final blockedByOther = _chatController!.isBlockedByOther.value;
      final otherName = _chatController!.otherParticipant?.name ?? _trainerName ?? 'This user';
      final isUnblocking = _chatController!.isLoading.value;

      if (blockedByOther || blockedByMe) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.primaryGray, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (blockedByOther)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.block, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('$otherName has blocked you. You cannot send messages.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                        ),
                      ],
                    ),
                  ),
                if (blockedByMe) ...[
                  if (blockedByOther) const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isUnblocking ? null : _onUnblockUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isUnblocking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                          : const Icon(Icons.lock_open_outlined),
                      label: Text(
                        'Unblock $otherName',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.primaryGray, width: 1)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: AppColors.onSurface),
              onPressed: _showAttachmentOptions,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.primaryGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.primaryGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.accent, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _chatController!.notifyTypingInRoom,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final isSending = _chatController!.isSending.value;
              return IconButton(
                icon: isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, color: AppColors.accent),
                onPressed: isSending ? null : _sendMessage,
              );
            }),
          ],
        ),
      );
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildAppBarTitle() {
    if (_chatController == null) {
      return Text(_trainerName ?? 'Chat', style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent));
    }

    return Obx(() {
      // Rebuild when messages load so participant profiles are available.
      _chatController!.messages.length;
      _chatController!.isOtherUserTyping.value;
      final other = _chatController!.otherParticipant;
      final name = other?.name ?? _trainerName ?? 'User';
      final imageUrl = other?.imageUrl;
      final isOnline = other?.isOnlineNow ?? false;
      final isTyping = _chatController!.isOtherUserTyping.value;
      final statusText = isTyping ? 'typing...' : (isOnline ? 'Online' : 'Offline');
      final statusColor = isTyping ? AppColors.accent : (isOnline ? Colors.green : AppColors.primaryGrayDark);

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeCircleNetworkAvatar(
            radius: 20,
            imageUrl: imageUrl,
            backgroundColor: AppColors.accent.withOpacity(0.15),
            fallback: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: isTyping ? AppColors.accent : (isOnline ? Colors.green : AppColors.primaryGray), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(statusText, style: AppTextStyles.labelSmall.copyWith(color: statusColor)),
                  ],
                ),
                if (_programTitle != null)
                  Text(
                    _programTitle!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.onPrimary.withOpacity(0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: _buildAppBarTitle(),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () {
            _chatController?.stopTypingInRoom();
            Get.back();
          },
        ),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: _showReportBlockOptions)],
      ),
      body: _chatController == null
          ? const Center(child: CircularProgressIndicator())
          : Obx(() {
              final messages = _chatController!.messages;
              final isLoading = _chatController!.isLoadingMessages.value;
              final isLoadingMore = _chatController!.isLoadingMoreMessages.value;

              return Column(
                children: [
                  // Messages list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _chatController!.refreshMessages(),
                      child: isLoading && messages.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : messages.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.primaryGray),
                                    const SizedBox(height: 16),
                                    Text('No messages yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                                    const SizedBox(height: 8),
                                    Text('Start the conversation!', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                                  ],
                                ),
                              ],
                            )
                          : ListView.builder(
                              reverse: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount: messages.length + (isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (isLoadingMore && index == messages.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                final message = messages[index];
                                final isCurrentUser = message.senderId == _chatController!.currentUserId;
                                final bubble = ChatMessageBubble(message: message, isCurrentUser: isCurrentUser, currentUserId: _chatController!.currentUserId);

                                if (isCurrentUser && !message.isPending && !message.id.startsWith('temp_')) {
                                  return GestureDetector(onLongPress: () => _showMessageOptions(message), child: bubble);
                                }

                                return bubble;
                              },
                            ),
                    ),
                  ),

                  // Recording indicator
                  if (_isRecording)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.error,
                      child: Row(
                        children: [
                          const Icon(Icons.mic, color: AppColors.onError),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Recording: ${_formatDuration(_recordingDuration)}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onError)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send, color: AppColors.onError),
                            onPressed: () => _stopRecording(true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.onError),
                            onPressed: () => _stopRecording(false),
                          ),
                        ],
                      ),
                    ),

                  // Input / block status area
                  if (!_isRecording) _buildChatBottomBar(),
                ],
              );
            }),
    );
  }
}

class _MediaComposerSheet extends StatefulWidget {
  const _MediaComposerSheet({required this.initialMedia, required this.chatController, required this.onSent});

  final List<_PendingMedia> initialMedia;
  final ChatController chatController;
  final VoidCallback onSent;

  @override
  State<_MediaComposerSheet> createState() => _MediaComposerSheetState();
}

class _MediaComposerSheetState extends State<_MediaComposerSheet> {
  late final TextEditingController _captionController;
  late List<_PendingMedia> _items;
  late final bool _isVideoComposer;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
    _items = List<_PendingMedia>.from(widget.initialMedia);
    _isVideoComposer = _items.every((item) => item.type == 'video');
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _addMoreImages() async {
    final limit = AppConstants.maxChatImageAttachments;
    if (_items.length >= limit) {
      _showChatPhotoLimitSnackbar();
      return;
    }

    final images = await ImagePicker().pickMultiImage();
    if (images.isEmpty || !mounted) return;

    final remaining = limit - _items.length;
    final limited = images.length > remaining ? images.take(remaining).toList() : images;
    if (images.length > remaining) {
      _showChatPhotoLimitSnackbar(selectedCount: _items.length + images.length);
    }

    setState(() {
      _items.addAll(limited.map((image) => _PendingMedia(path: image.path, type: 'image', name: image.name)));
    });
  }

  Future<void> _sendMedia() async {
    if (_items.isEmpty || widget.chatController.isSending.value) return;

    final limit = AppConstants.maxChatImageAttachments;
    if (!_isVideoComposer && _items.length > limit) {
      _showChatPhotoLimitSnackbar(selectedCount: _items.length);
      return;
    }

    final caption = _captionController.text;
    final paths = _items.map((item) => item.path).toList();
    final type = _items.first.type;

    Navigator.pop(context);
    await widget.chatController.sendMediaMessage(filePaths: paths, type: type, caption: caption);
    widget.onSent();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(_isVideoComposer ? 'Send video' : 'Send photos', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.type == 'image'
                              ? Image.file(File(item.path), width: 108, height: 108, fit: BoxFit.cover)
                              : Container(
                                  width: 108,
                                  height: 108,
                                  color: AppColors.primaryGray.withOpacity(0.25),
                                  child: const Icon(Icons.videocam, size: 40, color: AppColors.onSurface),
                                ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: AppColors.onError,
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(28, 28),
                            ),
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              setState(() {
                                _items.removeAt(index);
                                if (_items.isEmpty) Navigator.pop(context);
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (!_isVideoComposer) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${_items.length}/${AppConstants.maxChatImageAttachments} photos', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _items.length >= AppConstants.maxChatImageAttachments ? null : _addMoreImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.accent),
                    label: Text('Add more photos', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _captionController,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Add a caption...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Obx(() {
                final isSending = widget.chatController.isSending.value;
                return ElevatedButton(
                  onPressed: isSending || _items.isEmpty ? null : _sendMedia,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSending
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                      : Text(
                          'Send',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w600),
                        ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
