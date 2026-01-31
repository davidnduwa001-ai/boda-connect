import 'dart:async';
import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/models/custom_offer_model.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/custom_offer_provider.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/contact_detection_service.dart';
import 'package:boda_connect/core/services/presence_service.dart';
import 'package:boda_connect/core/services/storage_service.dart';
import 'package:boda_connect/core/services/suspension_service.dart';
import 'package:boda_connect/features/chat/presentation/providers/chat_provider.dart';
import 'package:boda_connect/features/chat/presentation/widgets/create_offer_dialog.dart';
import 'package:boda_connect/features/chat/presentation/widgets/client_price_proposal_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {

  const ChatDetailScreen({
    super.key,
    this.chatPreview,
    this.conversationId,
    this.otherUserId,
    this.otherUserName,
  });

  final dynamic chatPreview;
  final String? conversationId;
  final String? otherUserId;
  final String? otherUserName;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _actualConversationId;
  bool _isLoadingConversation = false;

  // Start with empty messages - will load from Firestore
  final List<ChatMessage> _messages = [];

  // No active proposal by default - will be set when supplier sends one
  ProposalInfo? _activeProposal;

  // Real-time message subscription
  StreamSubscription? _messagesSubscription;

  // Presence tracking
  final PresenceService _presenceService = PresenceService();
  StreamSubscription<UserPresence>? _presenceSubscription;
  UserPresence _otherUserPresence = UserPresence(isOnline: false, lastSeen: null);

  @override
  void initState() {
    super.initState();
    _actualConversationId = widget.conversationId;

    debugPrint('📱 ChatDetailScreen initialized:');
    debugPrint('   - conversationId: ${widget.conversationId}');
    debugPrint('   - otherUserId: ${widget.otherUserId}');
    debugPrint('   - otherUserName: ${widget.otherUserName}');

    // Subscribe to other user's presence status
    _subscribeToPresence();

    // If we have a conversation ID, subscribe immediately
    // Otherwise, try to initialize the conversation
    if (_actualConversationId != null) {
      _subscribeToMessages();
    } else if (widget.otherUserId != null && widget.otherUserId!.isNotEmpty) {
      // Try to find or create conversation when screen opens
      _initializeConversation();
    } else {
      debugPrint('⚠️ No otherUserId provided - cannot initialize conversation');
    }
  }

  /// Subscribe to other user's presence updates
  void _subscribeToPresence() {
    if (widget.otherUserId == null || widget.otherUserId!.isEmpty) return;

    _presenceSubscription = _presenceService
        .getUserPresence(widget.otherUserId!)
        .listen((presence) {
      if (mounted) {
        setState(() {
          _otherUserPresence = presence;
        });
      }
    });
  }

  /// Show snackbar safely (deferred if called during build)
  void _showSnackBar(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }

  /// Initialize conversation when opening chat without existing conversationId
  Future<void> _initializeConversation() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      debugPrint('❌ Cannot initialize conversation: user not authenticated');
      if (mounted) {
        setState(() => _isLoadingConversation = false);
        _showSnackBar('Utilizador não autenticado');
      }
      return;
    }

    if (widget.otherUserId == null || widget.otherUserId!.isEmpty) {
      debugPrint('❌ Cannot initialize conversation: otherUserId is null or empty');
      if (mounted) {
        setState(() => _isLoadingConversation = false);
        _showSnackBar('Fornecedor não encontrado');
      }
      return;
    }

    setState(() => _isLoadingConversation = true);

    // For suppliers: use the supplier document ID (not auth UID)
    // This is important because conversations are created with supplier.id, not supplier.userId
    String? supplierDocId;
    if (currentUser.userType.name == 'supplier') {
      final supplier = ref.read(supplierProvider).currentSupplier;
      supplierDocId = supplier?.id;
      debugPrint('   - supplier.id (doc): $supplierDocId');
    }

    debugPrint('🔄 Initializing conversation:');
    debugPrint('   - currentUser.uid: ${currentUser.uid}');
    debugPrint('   - currentUser.userType: ${currentUser.userType.name}');
    debugPrint('   - otherUserId: ${widget.otherUserId}');

    // Determine the correct IDs to use for conversation lookup
    // When supplier: use supplier document ID (or fall back to auth UID)
    // When client: use auth UID for clientId, otherUserId (supplier doc ID) for supplierId
    final effectiveSupplierId = currentUser.userType.name == 'supplier'
        ? (supplierDocId ?? currentUser.uid)
        : widget.otherUserId!;

    // For suppliers: also pass auth UID to search for legacy conversations
    // Legacy conversations may have been created with supplier.userId instead of supplier.id
    final supplierAuthUid = currentUser.userType.name == 'supplier' ? currentUser.uid : null;

    try {
      final result = await ref.read(chatActionsProvider.notifier).getOrCreateConversation(
        clientId: currentUser.userType.name == 'client' ? currentUser.uid : widget.otherUserId!,
        supplierId: effectiveSupplierId,
        clientName: currentUser.userType.name == 'client' ? currentUser.name : widget.otherUserName,
        supplierName: currentUser.userType.name == 'supplier' ? currentUser.name : widget.otherUserName,
        supplierAuthUid: supplierAuthUid,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⏰ Conversation initialization timed out');
          throw Exception('Tempo esgotado ao criar conversa');
        },
      );

      result.fold(
        (failure) {
          debugPrint('❌ Failed to initialize conversation: ${failure.message}');
          if (mounted) {
            setState(() => _isLoadingConversation = false);
            _showSnackBar('Erro: ${failure.message}');
          }
        },
        (conversation) {
          debugPrint('✅ Conversation initialized: ${conversation.id}');
          if (mounted) {
            setState(() {
              _actualConversationId = conversation.id;
              _isLoadingConversation = false;
            });
            // Now subscribe to messages with the new conversation ID
            _subscribeToMessages();
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Exception during conversation initialization: $e');
      if (mounted) {
        setState(() => _isLoadingConversation = false);
        _showSnackBar('Erro ao iniciar conversa: $e');
      }
    }
  }

  /// Subscribe to real-time message updates from Firestore
  void _subscribeToMessages() {
    // Cancel any existing subscription first
    _messagesSubscription?.cancel();
    _messagesSubscription = null;

    // Use _actualConversationId if set, otherwise fall back to widget.conversationId
    final conversationId = _actualConversationId ?? widget.conversationId;
    if (conversationId == null) {
      debugPrint('⚠️ No conversation ID - chat will remain empty until conversation is created');
      return;
    }

    debugPrint('🔄 Subscribing to real-time messages for conversation: $conversationId');

    // Get the messages stream from repository
    final messagesStream = ref.read(chatRepositoryProvider).getMessages(conversationId);

    // Subscribe to the stream for real-time updates
    _messagesSubscription = messagesStream.listen(
      (either) {
        either.fold(
          (failure) {
            debugPrint('❌ Failed to load messages: ${failure.message}');
          },
          (messageEntities) {
            if (mounted) {
              setState(() {
                // Convert MessageEntity to ChatMessage
                final currentUserId = ref.read(currentUserProvider)?.uid;
                final firestoreMessages = messageEntities.map((entity) {
                  // Convert QuoteDataEntity to Map for quote messages
                  Map<String, dynamic>? quoteDataMap;
                  if (entity.quoteData != null) {
                    quoteDataMap = {
                      'packageId': entity.quoteData!.packageId,
                      'packageName': entity.quoteData!.packageName,
                      'price': entity.quoteData!.price,
                      'notes': entity.quoteData!.notes,
                      'status': entity.quoteData!.status,
                    };
                  }
                  return ChatMessage(
                    id: entity.id,
                    text: entity.text ?? '',
                    isFromMe: entity.senderId == currentUserId,
                    timestamp: entity.timestamp,
                    isFlagged: false,
                    type: entity.type.name,
                    quoteData: quoteDataMap,
                  );
                }).toList();

                // Messages come from Firestore in descending order (newest first)
                // Reverse them so oldest messages appear at top of chat
                final sortedMessages = firestoreMessages.reversed.toList();

                // Update messages list
                _messages.clear();
                _messages.addAll(sortedMessages);
              });

              // Auto-scroll to bottom when new messages arrive
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              // Auto-mark incoming messages as read
              final userId = ref.read(currentUserProvider)?.uid;
              if (userId != null) {
                _markMessagesAsRead(conversationId, messageEntities, userId);
              }

              debugPrint('✅ Real-time update: ${messageEntities.length} messages');
            }
          },
        );
      },
      onError: (error) {
        debugPrint('❌ Stream error: $error');
      },
    );
  }

  /// Mark incoming messages as read automatically
  void _markMessagesAsRead(String conversationId, List<dynamic> messageEntities, String currentUserId) {
    // Find unread messages that are NOT from the current user
    final unreadMessages = messageEntities.where((entity) {
      final isFromOther = entity.senderId != currentUserId;
      final isUnread = entity.isRead != true;
      return isFromOther && isUnread;
    }).toList();

    if (unreadMessages.isEmpty) return;

    // Mark each unread message as read
    for (final message in unreadMessages) {
      ref.read(chatRepositoryProvider).markMessageAsRead(
        conversationId: conversationId,
        messageId: message.id,
        userId: currentUserId,
      );
    }

    // Also mark the conversation as read to reset unread count
    ref.read(chatRepositoryProvider).markConversationAsRead(
      conversationId: conversationId,
      userId: currentUserId,
    );

    debugPrint('✅ Marked ${unreadMessages.length} messages as read');
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel(); // Clean up real-time subscription
    _presenceSubscription?.cancel(); // Clean up presence subscription
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();

    // Detect contact information in the message
    final detectionResult = ContactDetectionService.analyzeMessage(messageText);

    // If high-risk content is detected, block and show warning
    if (detectionResult.shouldBlockMessage()) {
      _showContactDetectionDialog(
        title: 'Mensagem Bloqueada',
        message: detectionResult.getWarningMessage(),
        isBlocked: true,
      );
      return;
    }

    // If medium/low risk, show warning but allow sending
    if (detectionResult.shouldWarnUser()) {
      _showContactDetectionDialog(
        title: 'Atenção',
        message: detectionResult.getWarningMessage(),
        isBlocked: false,
        onProceed: () {
          _actualSendMessage(messageText, isFlagged: true);
        },
      );
      return;
    }

    // Clean message - send normally
    _actualSendMessage(messageText, isFlagged: false);
  }

  Future<void> _actualSendMessage(String text, {required bool isFlagged}) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    // Check if we have otherUserId
    if (widget.otherUserId == null || widget.otherUserId!.isEmpty) {
      debugPrint('❌ Cannot send message: otherUserId is null or empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destinatário não encontrado')),
      );
      return;
    }

    // Get or create conversation ID if not already set
    if (_actualConversationId == null) {
      setState(() => _isLoadingConversation = true);

      debugPrint('📝 Creating conversation before sending message...');

      // For suppliers: use the supplier document ID (not auth UID)
      String? supplierDocId;
      if (currentUser.userType.name == 'supplier') {
        final supplier = ref.read(supplierProvider).currentSupplier;
        supplierDocId = supplier?.id;
      }

      final effectiveSupplierId = currentUser.userType.name == 'supplier'
          ? (supplierDocId ?? currentUser.uid)
          : widget.otherUserId!;

      // For suppliers: also pass auth UID to search for legacy conversations
      final supplierAuthUid = currentUser.userType.name == 'supplier' ? currentUser.uid : null;

      final result = await ref.read(chatActionsProvider.notifier).getOrCreateConversation(
        clientId: currentUser.userType.name == 'client' ? currentUser.uid : widget.otherUserId!,
        supplierId: effectiveSupplierId,
        clientName: currentUser.userType.name == 'client' ? currentUser.name : widget.otherUserName,
        supplierName: currentUser.userType.name == 'supplier' ? currentUser.name : widget.otherUserName,
        supplierAuthUid: supplierAuthUid,
      );

      // Handle result
      final conversationCreated = result.fold(
        (failure) {
          debugPrint('❌ Failed to create conversation: ${failure.message}');
          if (mounted) {
            setState(() => _isLoadingConversation = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Falha ao criar conversa: ${failure.message}')),
            );
          }
          return false;
        },
        (conversation) {
          debugPrint('✅ Conversation created: ${conversation.id}');
          if (mounted) {
            setState(() {
              _actualConversationId = conversation.id;
              _isLoadingConversation = false;
            });
            // Start subscribing to messages now that conversation is created
            _subscribeToMessages();
          }
          return true;
        },
      );

      // If conversation creation failed, don't continue
      if (!conversationCreated || _actualConversationId == null) {
        return;
      }
    }

    final conversationId = _actualConversationId;
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversa não inicializada')),
      );
      return;
    }

    // Clear input immediately for better UX
    _messageController.clear();

    debugPrint('📤 Sending message to conversation: $conversationId');

    // Send to Firestore in background
    final sendResult = await ref.read(chatActionsProvider.notifier).sendTextMessage(
      conversationId: conversationId,
      receiverId: widget.otherUserId!,
      text: text,
      senderName: currentUser.name,
    );

    sendResult.fold(
      (failure) {
        // Show error - real-time subscription will handle successful messages
        debugPrint('❌ Failed to send message: ${failure.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao enviar: ${failure.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      (message) {
        // Success - message sent to Firestore
        // Real-time subscription will automatically add it to the chat
        debugPrint('✅ Message sent to Firestore: ${message.id}');

        // Record violation if message was flagged for contact sharing
        if (isFlagged) {
          _recordContactSharingViolation(
            messageId: message.id,
            messageText: text,
          );
        }
      },
    );
  }

  /// Records a contact sharing violation when user sends a flagged message
  Future<void> _recordContactSharingViolation({
    required String messageId,
    required String messageText,
  }) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      final suspensionService = SuspensionService();
      await suspensionService.recordViolation(
        currentUser.uid,
        PolicyViolation(
          type: ViolationType.contactSharing,
          description: 'Tentativa de partilha de contacto detectada na mensagem',
          timestamp: DateTime.now(),
          relatedMessageId: messageId,
        ),
      );
      debugPrint('⚠️ Contact sharing violation recorded for user ${currentUser.uid}');
    } catch (e) {
      debugPrint('❌ Failed to record violation: $e');
    }
  }

  /// Show image picker options (camera or gallery)
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Enviar Imagem',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImagePickerOption(
                    icon: Icons.camera_alt,
                    label: 'Câmera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                  _buildImagePickerOption(
                    icon: Icons.photo_library,
                    label: 'Galeria',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.peachLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.peach, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.body),
        ],
      ),
    );
  }

  /// Pick an image and send it
  Future<void> _pickAndSendImage(ImageSource source) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilizador não autenticado')),
      );
      return;
    }

    // Ensure conversation exists
    if (_actualConversationId == null) {
      await _initializeConversation();
      if (_actualConversationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversa não inicializada')),
        );
        return;
      }
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text('A enviar imagem...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Upload image to Firebase Storage first
      final storageService = StorageService();
      final imageUrl = await storageService.uploadChatImage(
        _actualConversationId!,
        pickedFile,
      );

      // Send image message with the uploaded URL
      final result = await ref.read(chatActionsProvider.notifier).sendImageMessage(
        conversationId: _actualConversationId!,
        receiverId: widget.otherUserId!,
        imageUrl: imageUrl,
        senderName: currentUser.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      result.fold(
        (failure) {
          debugPrint('❌ Failed to send image: ${failure.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Falha ao enviar imagem: ${failure.message}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        (message) {
          debugPrint('✅ Image sent successfully: ${message.id}');
        },
      );
    } catch (e) {
      debugPrint('❌ Error picking/sending image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar imagem: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Navigate to user profile
  void _navigateToProfile() {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || widget.otherUserId == null) return;

    // If current user is client, navigate to supplier detail
    // If current user is supplier, navigate to client profile (if exists)
    if (currentUser.userType.name == 'client') {
      context.push(Routes.clientSupplierDetail, extra: widget.otherUserId);
    } else {
      // Suppliers viewing client profile - show a simple profile dialog
      _showClientProfileDialog();
    }
  }

  /// Show client profile dialog for suppliers
  void _showClientProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.peachLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(widget.otherUserName ?? 'C'),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.peachDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName ?? 'Cliente',
                    style: AppTextStyles.h3,
                  ),
                  Text(
                    _otherUserPresence.isOnline ? 'Online' : _otherUserPresence.getLastSeenText(),
                    style: AppTextStyles.caption.copyWith(
                      color: _otherUserPresence.isOnline ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProfileInfoRow(Icons.person, 'Cliente BODA CONNECT'),
            const SizedBox(height: 8),
            _buildProfileInfoRow(Icons.verified_user, 'Perfil Verificado'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(text, style: AppTextStyles.body),
      ],
    );
  }

  void _showContactDetectionDialog({
    required String title,
    required String message,
    required bool isBlocked,
    VoidCallback? onProceed,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isBlocked ? Icons.block : Icons.warning_amber_rounded,
              color: isBlocked ? AppColors.error : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 20, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A BODA CONNECT nunca lhe pedirá para comunicar fora da plataforma.',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
          if (!isBlocked && onProceed != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onProceed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
              child: const Text('Enviar Mesmo Assim'),
            ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Watch for offers in this conversation
    final conversationId = _actualConversationId;
    final offersState = conversationId != null
        ? ref.watch(chatOffersProvider(conversationId))
        : null;
    final latestPendingOffer = offersState?.latestPendingOffer;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Show pending offer banner if there's one (for buyers)
          if (latestPendingOffer != null) _buildOfferBanner(latestPendingOffer),
          // Only show proposal banner if there's an active proposal (legacy)
          if (_activeProposal != null && latestPendingOffer == null) _buildProposalBanner(),
          Expanded(child: _buildMessagesList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Build an offer banner for pending offers
  Widget _buildOfferBanner(CustomOfferModel offer) {
    final currentUser = ref.watch(currentUserProvider);
    final isSupplier = currentUser?.userType.name == 'supplier';
    final isBuyer = currentUser?.uid == offer.buyerId;

    // Determine if this user sent or received the offer
    // For supplier offers: supplier sent, buyer received
    // For client proposals: buyer sent, supplier received
    final isClientProposal = offer.isClientProposal;
    final didCurrentUserSend = isClientProposal ? isBuyer : isSupplier;
    final canAcceptReject = isClientProposal ? isSupplier : isBuyer;

    return GestureDetector(
      onTap: () => _showOfferDetails(offer),
      child: Container(
        margin: const EdgeInsets.all(AppDimensions.sm),
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.peach, AppColors.peachDark],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Icon(Icons.local_offer_outlined, color: AppColors.white),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    didCurrentUserSend ? 'Proposta Enviada' : 'Proposta Recebida',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.white.withValues(alpha: 0.9)),
                  ),
                  Text(
                    '${isClientProposal ? 'Proposta do Cliente' : (offer.basePackageName ?? 'Proposta Personalizada')} - ${_formatPrice(offer.customPrice)}',
                    style: AppTextStyles.body.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (canAcceptReject)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Ver', style: AppTextStyles.bodySmall.copyWith(color: AppColors.peachDark, fontWeight: FontWeight.w600)),
              )
            else if (didCurrentUserSend)
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.white),
                onPressed: () => _cancelOffer(offer.id),
                tooltip: 'Cancelar proposta',
              ),
          ],
        ),
      ),
    );
  }

  /// Show offer details in a bottom sheet
  void _showOfferDetails(CustomOfferModel offer) {
    final currentUser = ref.read(currentUserProvider);
    final isBuyer = currentUser?.uid == offer.buyerId;
    final isSupplier = currentUser?.userType.name == 'supplier';

    // Determine if this user can accept/reject
    // For supplier offers: buyer accepts/rejects
    // For client proposals: supplier accepts/rejects
    final isClientProposal = offer.isClientProposal;
    final canAcceptReject = isClientProposal ? isSupplier : isBuyer;
    final canCancel = isClientProposal ? isBuyer : isSupplier;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.peachLight,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: const Icon(Icons.local_offer_outlined, color: AppColors.peachDark, size: 28),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Proposta', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                              Text(offer.basePackageName ?? 'Proposta Personalizada', style: AppTextStyles.h3),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(offer.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _getStatusText(offer.status),
                            style: AppTextStyles.caption.copyWith(
                              color: _getStatusColor(offer.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    Text('Descrição', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppDimensions.sm),
                    Text(offer.description, style: AppTextStyles.body),
                    if (offer.deliveryTime != null) ...[
                      const SizedBox(height: AppDimensions.md),
                      _buildProposalDetail(Icons.timer_outlined, 'Tempo de entrega', offer.deliveryTime!),
                    ],
                    if (offer.validUntil != null) ...[
                      const SizedBox(height: AppDimensions.sm),
                      _buildProposalDetail(Icons.event_outlined, 'Válida até', _formatDate(offer.validUntil!)),
                    ],
                    const SizedBox(height: AppDimensions.lg),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valor Total', style: AppTextStyles.bodyLarge),
                          Text(_formatPrice(offer.customPrice), style: AppTextStyles.h2.copyWith(color: AppColors.peachDark)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    // Action buttons based on user role and offer status
                    if (offer.status == OfferStatus.pending) ...[
                      if (canAcceptReject)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showRejectOfferDialog(offer.id, isClientProposal: isClientProposal);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Recusar'),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.md),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  if (isClientProposal) {
                                    _acceptClientProposal(offer);
                                  } else {
                                    _showAcceptOfferDialog(offer.id);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: AppColors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Aceitar Proposta'),
                              ),
                            ),
                          ],
                        )
                      else if (canCancel)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _cancelOffer(offer.id);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancelar Proposta'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OfferStatus status) {
    switch (status) {
      case OfferStatus.pending:
        return AppColors.warning;
      case OfferStatus.accepted:
        return AppColors.success;
      case OfferStatus.rejected:
        return AppColors.error;
      case OfferStatus.cancelled:
        return AppColors.gray700;
      case OfferStatus.expired:
        return AppColors.gray400;
    }
  }

  String _getStatusText(OfferStatus status) {
    switch (status) {
      case OfferStatus.pending:
        return 'Pendente';
      case OfferStatus.accepted:
        return 'Aceite';
      case OfferStatus.rejected:
        return 'Rejeitada';
      case OfferStatus.cancelled:
        return 'Cancelada';
      case OfferStatus.expired:
        return 'Expirada';
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.gray900),
        onPressed: () => context.pop(),
      ),
      title: GestureDetector(
        onTap: _navigateToProfile,
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.peachLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(widget.otherUserName ?? 'U'),
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.peachDark),
                    ),
                  ),
                ),
                // Online indicator - only show when user is online
                if (_otherUserPresence.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.otherUserName ?? 'Usuário',
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: AppColors.info),
                    ],
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _otherUserPresence.getLastSeenText(),
                          style: AppTextStyles.caption.copyWith(
                            color: _otherUserPresence.isOnline ? AppColors.success : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• Toque para ver perfil',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.peach,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Phone calls not allowed - text messages only
        IconButton(icon: const Icon(Icons.more_vert, color: AppColors.gray700), onPressed: () {}),
      ],
    );
  }

  Widget _buildProposalBanner() {
    final proposal = _activeProposal!; // Safe because we only call this when _activeProposal != null
    return GestureDetector(
      onTap: () => _showProposalDetails(proposal),
      child: Container(
        margin: const EdgeInsets.all(AppDimensions.sm),
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.peach, AppColors.peachDark],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Icon(Icons.description_outlined, color: AppColors.white),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Proposta Recebida', style: AppTextStyles.bodySmall.copyWith(color: AppColors.white.withValues(alpha: 0.9))),
                  Text('${proposal.packageName} - ${_formatPrice(proposal.price)}', style: AppTextStyles.body.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Ver', style: AppTextStyles.bodySmall.copyWith(color: AppColors.peachDark, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    // Show loading indicator while initializing conversation
    if (_isLoadingConversation) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.peach),
            SizedBox(height: 16),
            Text(
              'Iniciando conversa...',
              style: AppTextStyles.body,
            ),
          ],
        ),
      );
    }

    // Show empty state if no messages yet
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.gray300,
            ),
            const SizedBox(height: 16),
            Text(
              'Inicie uma conversa',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Envie uma mensagem para ${widget.otherUserName ?? 'o fornecedor'}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.gray400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showTimestamp = index == 0 ||
            _messages[index - 1].timestamp.day != message.timestamp.day;

        return Column(
          children: [
            if (showTimestamp) _buildDateSeparator(message.timestamp),
            _buildMessageBubble(message),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.gray200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_formatDate(date), style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    // Special rendering for quote/proposal messages
    if (message.isQuote && message.quoteData != null) {
      return _buildProposalCard(message);
    }

    return Align(
      alignment: message.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: message.isFromMe ? AppColors.peach : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isFromMe ? 16 : 4),
            bottomRight: Radius.circular(message.isFromMe ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: AppTextStyles.body.copyWith(color: message.isFromMe ? AppColors.white : AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isFlagged) ...[
                  Tooltip(
                    message: 'Mensagem sinalizada para revisão',
                    child: Icon(
                      Icons.flag_outlined,
                      size: 12,
                      color: message.isFromMe
                          ? AppColors.white.withValues(alpha: 0.7)
                          : AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  _formatTime(message.timestamp),
                  style: AppTextStyles.caption.copyWith(
                    color: message.isFromMe ? AppColors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                if (message.isFromMe) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all, size: 14, color: AppColors.white.withValues(alpha: 0.7)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build a special card for proposal/quote messages
  Widget _buildProposalCard(ChatMessage message) {
    final quoteData = message.quoteData!;
    final price = quoteData['price'] as int? ?? 0;
    final packageName = quoteData['packageName'] as String? ?? 'Proposta Personalizada';
    final notes = quoteData['notes'] as String? ?? '';
    final status = quoteData['status'] as String? ?? 'pending';

    final isPending = status == 'pending';
    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';

    Color statusColor = AppColors.warning;
    String statusText = 'Pendente';
    IconData statusIcon = Icons.schedule;

    if (isAccepted) {
      statusColor = AppColors.success;
      statusText = 'Aceite';
      statusIcon = Icons.check_circle;
    } else if (isRejected) {
      statusColor = AppColors.error;
      statusText = 'Rejeitada';
      statusIcon = Icons.cancel;
    }

    return Align(
      alignment: message.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.peach.withValues(alpha: 0.3), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with icon and title
            Container(
              padding: const EdgeInsets.all(AppDimensions.sm),
              decoration: BoxDecoration(
                color: AppColors.peach.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.peach,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_offer, color: AppColors.white, size: 20),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          packageName,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          message.isFromMe ? 'Proposta enviada' : 'Proposta recebida',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusText, style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Padding(
              padding: const EdgeInsets.all(AppDimensions.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Valor: ', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                      Text(
                        '${_formatPrice(price)} AOA',
                        style: AppTextStyles.h3.copyWith(color: AppColors.peach, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      notes,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Action buttons (only for pending proposals received by the user)
            if (isPending && !message.isFromMe) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _handleRejectProposal(message),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Rejeitar'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleAcceptProposal(message),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Aceitar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Timestamp
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.sm, bottom: AppDimensions.xs),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatTime(message.timestamp),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle accepting a proposal
  Future<void> _handleAcceptProposal(ChatMessage message) async {
    // TODO: Implement accept proposal flow
    // This should show a dialog to collect event details and call the acceptOffer method
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de aceitar proposta em desenvolvimento')),
    );
  }

  /// Handle rejecting a proposal
  Future<void> _handleRejectProposal(ChatMessage message) async {
    // TODO: Implement reject proposal flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de rejeitar proposta em desenvolvimento')),
    );
  }

  /// Format price with thousand separators
  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Widget _buildMessageInput() {
    final isEnabled = !_isLoadingConversation;
    final currentUser = ref.watch(currentUserProvider);
    final isSupplier = currentUser?.userType.name == 'supplier';

    return Container(
      padding: EdgeInsets.fromLTRB(AppDimensions.md, AppDimensions.sm, AppDimensions.md, AppDimensions.md + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          // Image attachment button for both clients and suppliers
          IconButton(
            icon: Icon(Icons.image_outlined, color: isEnabled ? AppColors.gray700 : AppColors.gray300),
            tooltip: 'Enviar Imagem',
            onPressed: isEnabled ? _showImagePickerOptions : null,
          ),
          // Show offer button for suppliers OR proposal button for clients
          if (isSupplier)
            IconButton(
              icon: Icon(Icons.local_offer_outlined, color: isEnabled ? AppColors.peach : AppColors.gray300),
              tooltip: 'Criar Proposta',
              onPressed: isEnabled ? _showCreateOfferDialog : null,
            )
          else
            IconButton(
              icon: Icon(Icons.monetization_on_outlined, color: isEnabled ? AppColors.peach : AppColors.gray300),
              tooltip: 'Propor Preço',
              onPressed: isEnabled ? _showClientPriceProposalDialog : null,
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isEnabled ? AppColors.gray100 : AppColors.gray50,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                enabled: isEnabled,
                decoration: InputDecoration(
                  hintText: isEnabled ? 'Escreva uma mensagem...' : 'Aguarde...',
                  hintStyle: AppTextStyles.body.copyWith(color: AppColors.gray400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: AppTextStyles.body,
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          GestureDetector(
            onTap: isEnabled ? _sendMessage : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isEnabled ? AppColors.peach : AppColors.gray300,
                shape: BoxShape.circle,
              ),
              child: _isLoadingConversation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showProposalDetails(ProposalInfo proposal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.peachLight,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: const Icon(Icons.description_outlined, color: AppColors.peachDark, size: 28),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Proposta', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                              Text(proposal.packageName, style: AppTextStyles.h3),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('Pendente', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    _buildProposalDetail(Icons.calendar_today_outlined, 'Data do Evento', _formatDate(proposal.eventDate)),
                    _buildProposalDetail(Icons.timer_outlined, 'Válida até', _formatDate(proposal.validUntil)),
                    const SizedBox(height: AppDimensions.lg),
                    Text('Serviços Incluídos', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppDimensions.sm),
                    ...proposal.services.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(s, style: AppTextStyles.body),
                      ],),
                    ),),
                    const SizedBox(height: AppDimensions.lg),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.md),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valor Total', style: AppTextStyles.bodyLarge),
                          Text(_formatPrice(proposal.price), style: AppTextStyles.h2.copyWith(color: AppColors.peachDark)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Recusar'),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // Navigate to checkout
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Aceitar Proposta'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.gray400),
          const SizedBox(width: AppDimensions.sm),
          Text('$label: ', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} Kz';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Show dialog for supplier to create a custom offer
  Future<void> _showCreateOfferDialog() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    // Get supplier's packages for the dialog
    final supplierState = ref.read(supplierProvider);
    final packages = supplierState.packages;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateOfferDialog(
        packages: packages,
        buyerName: widget.otherUserName,
      ),
    );

    if (result == null || !mounted) return;

    // Get conversation ID
    final conversationId = _actualConversationId;
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversa não inicializada'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Create the offer using the provider
    final offersNotifier = ref.read(chatOffersProvider(conversationId).notifier);

    final offerResult = await offersNotifier.createOffer(
      sellerId: currentUser.uid,
      buyerId: widget.otherUserId!,
      sellerName: currentUser.name ?? 'Fornecedor',
      buyerName: widget.otherUserName,
      customPrice: result['customPrice'] as int,
      description: result['description'] as String,
      basePackageId: result['basePackageId'] as String?,
      basePackageName: result['basePackageName'] as String?,
      deliveryTime: result['deliveryTime'] as String?,
      validUntil: result['validUntil'] as DateTime?,
    );

    if (!mounted) return;

    if (offerResult != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposta enviada com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final errorState = ref.read(chatOffersProvider(conversationId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorState.error ?? 'Erro ao enviar proposta'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Show dialog for client to propose a price to supplier
  Future<void> _showClientPriceProposalDialog() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ClientPriceProposalDialog(
        supplierName: widget.otherUserName,
      ),
    );

    if (result == null || !mounted) return;

    // Get conversation ID
    final conversationId = _actualConversationId;
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversa não inicializada'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Create the offer using the provider (client is the "seller" in this case - initiator)
    // But we swap roles: client proposes to supplier, supplier decides
    final offersNotifier = ref.read(chatOffersProvider(conversationId).notifier);

    // For client proposals, the client is the buyer proposing to the supplier (seller)
    final offerResult = await offersNotifier.createOffer(
      sellerId: widget.otherUserId!, // Supplier receives the proposal
      buyerId: currentUser.uid, // Client sends the proposal
      sellerName: widget.otherUserName ?? 'Fornecedor',
      buyerName: currentUser.name ?? 'Cliente',
      customPrice: result['customPrice'] as int,
      description: result['description'] as String,
      basePackageId: null,
      basePackageName: null,
      deliveryTime: null,
      validUntil: DateTime.now().add(const Duration(days: 7)), // 7 days validity
      eventDate: result['eventDate'] as DateTime?,
      initiatedBy: 'buyer', // Mark this as a client-initiated proposal
    );

    if (!mounted) return;

    if (offerResult != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposta de preço enviada ao fornecedor!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final errorState = ref.read(chatOffersProvider(conversationId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorState.error ?? 'Erro ao enviar proposta'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Show dialog for buyer to accept an offer with event details
  Future<void> _showAcceptOfferDialog(String offerId) async {
    final eventNameController = TextEditingController();
    final eventLocationController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              const Text('Aceitar Proposta'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preencha os detalhes do seu evento para confirmar a reserva.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: eventNameController,
                  decoration: InputDecoration(
                    labelText: 'Nome do Evento *',
                    hintText: 'Ex: Casamento, Aniversário...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data do Evento *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDate(selectedDate)),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: eventLocationController,
                  decoration: InputDecoration(
                    labelText: 'Local (opcional)',
                    hintText: 'Ex: Luanda, Angola',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Observações (opcional)',
                    hintText: 'Detalhes adicionais...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (eventNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, insira o nome do evento'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'eventName': eventNameController.text.trim(),
                  'eventDate': selectedDate,
                  'eventLocation': eventLocationController.text.trim().isNotEmpty
                      ? eventLocationController.text.trim()
                      : null,
                  'notes': notesController.text.trim().isNotEmpty
                      ? notesController.text.trim()
                      : null,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Confirmar Reserva'),
            ),
          ],
        ),
      ),
    );

    eventNameController.dispose();
    eventLocationController.dispose();
    notesController.dispose();

    if (result == null || !mounted) return;

    final conversationId = _actualConversationId;
    if (conversationId == null) return;

    final offersNotifier = ref.read(chatOffersProvider(conversationId).notifier);
    final bookingId = await offersNotifier.acceptOffer(
      offerId: offerId,
      eventName: result['eventName'] as String,
      eventDate: result['eventDate'] as DateTime,
      eventLocation: result['eventLocation'] as String?,
      notes: result['notes'] as String?,
    );

    if (!mounted) return;

    if (bookingId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reserva #${bookingId.substring(0, 8)} criada com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final errorState = ref.read(chatOffersProvider(conversationId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorState.error ?? 'Erro ao aceitar proposta'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Accept a client proposal (supplier accepts the client's proposed price)
  Future<void> _acceptClientProposal(CustomOfferModel offer) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final conversationId = _actualConversationId;
    if (conversationId == null) return;

    // For client proposals, the supplier accepting creates a booking directly
    // using the event date from the proposal if available
    final eventName = offer.eventName ?? 'Evento';
    final eventDate = offer.eventDate ?? DateTime.now().add(const Duration(days: 7));

    final offersNotifier = ref.read(chatOffersProvider(conversationId).notifier);
    final bookingId = await offersNotifier.acceptOffer(
      offerId: offer.id,
      eventName: eventName,
      eventDate: eventDate,
    );

    if (!mounted) return;

    if (bookingId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proposta aceite! Reserva #${bookingId.substring(0, 8)} criada.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final errorState = ref.read(chatOffersProvider(conversationId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorState.error ?? 'Erro ao aceitar proposta'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Show dialog for buyer to reject an offer
  Future<void> _showRejectOfferDialog(String offerId, {bool isClientProposal = false}) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            const Text('Rejeitar Proposta'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tem certeza que deseja rejeitar esta proposta?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ex: Preço muito alto, data não disponível...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();

    if (confirmed != true || !mounted) return;

    final conversationId = _actualConversationId;
    if (conversationId == null) return;

    final offersNotifier = ref.read(chatOffersProvider(conversationId).notifier);
    final success = await offersNotifier.rejectOffer(
      offerId: offerId,
      reason: reason.isNotEmpty ? reason : null,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposta rejeitada'),
          backgroundColor: AppColors.gray700,
        ),
      );
    }
  }

  /// Cancel an offer (for suppliers)
  Future<void> _cancelOffer(String offerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Proposta?'),
        content: const Text(
          'Tem certeza que deseja cancelar esta proposta? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Sim, Cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final conversationId = _actualConversationId;
    if (conversationId == null) return;

    final offersNotifier = ref.read(chatOffersProvider(conversationId).notifier);
    final success = await offersNotifier.cancelOffer(offerId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposta cancelada'),
          backgroundColor: AppColors.gray700,
        ),
      );
    }
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.text,
    required this.isFromMe,
    required this.timestamp,
    this.isFlagged = false,
    this.type = 'text',
    this.quoteData,
  });
  final String id;
  final String text;
  final bool isFromMe;
  final DateTime timestamp;
  final bool isFlagged;
  final String type;
  final Map<String, dynamic>? quoteData;

  bool get isQuote => type == 'quote';
}

enum ProposalStatus { pending, accepted, rejected }

class ProposalInfo {
  ProposalInfo({required this.id, required this.packageName, required this.price, required this.eventDate, required this.status, required this.validUntil, required this.services});
  final String id;
  final String packageName;
  final int price;
  final DateTime eventDate;
  final DateTime validUntil;
  final ProposalStatus status;
  final List<String> services;
}
