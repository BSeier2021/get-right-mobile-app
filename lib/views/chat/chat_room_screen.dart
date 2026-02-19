import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_right/controllers/chat_controller.dart';
import 'package:get_right/models/report_block_model.dart';
import 'package:get_right/models/enrolled_program_model.dart';
import 'package:get_right/services/api_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/chat_message_bubble.dart';

/// Chat Room Screen - Full chat interface with trainer
class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _isRecorderInitialized = false;

  ChatController? _chatController;
  String? _conversationId;
  String? _trainerId;
  String? _trainerName;
  String? _programId;
  String? _programTitle;

  @override
  void initState() {
    super.initState();
    _initializeController();
    _initializeRecorder();
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

      if (mounted) {
        _loadChatData();
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      await _audioRecorder.openRecorder();
      setState(() {
        _isRecorderInitialized = true;
      });
    } catch (e) {
      // Silent fail - recorder will be initialized when needed
    }
  }

  void _loadChatData() {
    final args = Get.arguments;
    if (args is Map) {
      _conversationId = args['conversationId'];
      _trainerId = args['trainerId'];
      _trainerName = args['trainerName'];
      _programId = args['programId'];
      _programTitle = args['programTitle'];

      if (_conversationId != null && _chatController != null) {
        _chatController!.loadMessages(_conversationId!, trainerId: _trainerId, programId: _programId);
      } else if (_trainerId != null && _programId != null) {
        // Start new conversation
        _startNewConversation();
      }
    } else if (args is EnrolledProgramModel) {
      // Started from enrolled program
      final program = args;
      _trainerId = program.trainerId;
      _trainerName = program.trainerName;
      _programId = program.programId;
      _programTitle = program.programTitle;
      _startNewConversation();
    }
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
      await _chatController!.loadMessages(conversationId, trainerId: _trainerId, programId: _programId);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_isRecorderInitialized) {
      _audioRecorder.closeRecorder();
    }
    _recordingTimer?.cancel();
    _chatController?.stopPolling();
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

  Future<void> _pickImage() async {
    if (_chatController == null) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _chatController!.sendFileMessage(filePath: image.path, type: 'image', fileName: image.name);
      _scrollToBottom();
    }
  }

  Future<void> _pickVideo() async {
    if (_chatController == null) return;
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      await _chatController!.sendFileMessage(filePath: video.path, type: 'video', fileName: video.name);
      _scrollToBottom();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Check microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        Get.snackbar('Permission Denied', 'Microphone permission is required');
        return;
      }

      // Initialize recorder if not already initialized
      if (!_isRecorderInitialized) {
        await _audioRecorder.openRecorder();
        _isRecorderInitialized = true;
      }

      final directory = await getApplicationDocumentsDirectory();
      _recordingPath = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _audioRecorder.startRecorder(toFile: _recordingPath, codec: Codec.aacADTS);

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

    if (_isRecording && _recordingPath != null) {
      final path = _recordingPath!;
      await _audioRecorder.stopRecorder();

      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = 0;
      });

      if (send && _recordingDuration > 0 && _chatController != null) {
        await _chatController!.sendFileMessage(filePath: path, type: 'audio', fileName: 'audio_message.aac');
        _scrollToBottom();
      } else {
        // Delete unsent recording
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore
        }
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
              title: Text('Photo', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
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
              title: Text('Audio', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
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

  void _showReportBlockOptions() {
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
              leading: const Icon(Icons.flag, color: AppColors.error),
              title: Text('Report Trainer', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.error),
              title: Text('Block Trainer', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog();
              },
            ),
          ],
        ),
      ),
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

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_trainerName ?? 'Trainer', style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent)),
            if (_programTitle != null) Text(_programTitle!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onPrimary.withOpacity(0.7))),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: _showReportBlockOptions)],
      ),
      body: _chatController == null
          ? const Center(child: CircularProgressIndicator())
          : Obx(() {
              final messages = _chatController!.messages;
              final isLoading = _chatController!.isLoading.value;
              final isSending = _chatController!.isSending.value;

              return Column(
                children: [
                  // Messages list
                  Expanded(
                    child: isLoading && messages.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.primaryGray),
                                const SizedBox(height: 16),
                                Text('No messages yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                                const SizedBox(height: 8),
                                Text('Start the conversation!', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isCurrentUser = message.senderId == _chatController!.currentUserId;
                              return ChatMessageBubble(message: message, isCurrentUser: isCurrentUser, currentUserId: _chatController!.currentUserId);
                            },
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

                  // Input area
                  Container(
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
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: isSending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send, color: AppColors.accent),
                          onPressed: isSending ? null : _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
    );
  }
}
