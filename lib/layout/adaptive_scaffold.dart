import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/chat/data/api_service.dart';
import '../features/chat/data/chat_storage_service.dart';
import '../features/chat/data/message_model.dart';
import '../features/chat/ui/widgets/chat_input_field.dart';
import '../features/chat/ui/widgets/chat_message_list.dart';
import '../screens/branch/branch_screen.dart';
import '../core/app_config.dart';
import '../theme/app_colors.dart';
import '../widgets/uniguide_logo.dart';

class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({super.key});

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  bool _isLoading = false;
  bool _isInitializing = true;
  bool _showHistoryRetentionNotice = true;

  final String _appVersion = 'v1.1.0';

  final ApiService _apiService = ApiService();
  final ChatStorageService _chatStorageService = ChatStorageService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _latestAssistantMessageKey = GlobalKey();

  List<ChatSession> _chatSessions = [];
  String? _activeChatId;
  bool _userScrolledDuringRequest = false;

  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    _NavItem(
      label: 'Books',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
    ),
    _NavItem(
      label: 'PYQs',
      icon: Icons.quiz_outlined,
      selectedIcon: Icons.quiz,
    ),
    _NavItem(
      label: 'Notes',
      icon: Icons.sticky_note_2_outlined,
      selectedIcon: Icons.sticky_note_2,
    ),
    _NavItem(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatController.addListener(_handleComposerChanged);
    _loadChats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatController.removeListener(_handleComposerChanged);
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  ChatSession _createFreshSession() {
    return ChatSession.create(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      messages: const [],
    );
  }

  bool _isDraftSession(ChatSession session) => session.messages.isEmpty;

  ChatSession _ensureDraftSession(List<ChatSession> sessions) {
    for (final session in sessions) {
      if (_isDraftSession(session)) {
        return session;
      }
    }

    final draftSession = _createFreshSession();
    sessions.insert(0, draftSession);
    return draftSession;
  }

  ChatSession get _activeSession {
    if (_chatSessions.isEmpty) {
      final fallbackSession = _createFreshSession();
      _chatSessions = [fallbackSession];
      _activeChatId = fallbackSession.id;
      return fallbackSession;
    }

    return _chatSessions.firstWhere(
      (session) => session.id == _activeChatId,
      orElse: () {
        final fallbackSession = _chatSessions.first;
        _activeChatId = fallbackSession.id;
        return fallbackSession;
      },
    );
  }

  List<ChatMessage> get _messages => _activeSession.messages;

  ChatSession? _sessionForId(String id) {
    for (final session in _chatSessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  Future<void> _loadChats() async {
    final sessions = await _chatStorageService.loadSessions();

    if (!mounted) return;

    setState(() {
      if (sessions.isEmpty) {
        final initialSession = _createFreshSession();
        _chatSessions = [initialSession];
        _activeChatId = initialSession.id;
      } else {
        _chatSessions = List<ChatSession>.from(sessions)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final landingSession = _ensureDraftSession(_chatSessions);

        _chatSessions
          ..removeWhere((session) => session.id == landingSession.id)
          ..insert(0, landingSession);

        _activeChatId = landingSession.id;
      }

      _isInitializing = false;
    });

    await _persistChats();
  }

  Future<void> _prepareFreshChatLanding() async {
    if (_isInitializing) return;

    final draftSession = _ensureDraftSession(_chatSessions);

    if (!mounted) {
      _activeChatId = draftSession.id;
      return _persistChats();
    }

    setState(() {
      _chatSessions
        ..removeWhere((session) => session.id == draftSession.id)
        ..insert(0, draftSession);

      _activeChatId = draftSession.id;
      _chatController.clear();
      _isLoading = false;
    });

    await _persistChats();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _prepareFreshChatLanding();
    }
  }

  Future<void> _persistChats() {
    _chatSessions = _chatStorageService.limitSessions(_chatSessions);
    if (!_chatSessions.any((session) => session.id == _activeChatId)) {
      _activeChatId = _chatSessions.isEmpty ? null : _chatSessions.first.id;
    }
    return _chatStorageService.saveSessions(
      sessions: _chatSessions,
      activeChatId: _activeChatId,
    );
  }

  void _replaceSession(ChatSession updatedSession) {
    _chatSessions = _chatSessions
        .map(
          (session) =>
              session.id == updatedSession.id ? updatedSession : session,
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String _deriveTitle(List<ChatMessage> messages) {
    ChatMessage? firstUserMessage;

    for (final message in messages) {
      if (message.isUser) {
        firstUserMessage = message;
        break;
      }
    }

    final title = firstUserMessage?.text.trim() ?? '';

    if (title.isEmpty) return 'New chat';

    if (title.length <= 42) return title;

    return '${title.substring(0, 42).trimRight()}...';
  }

  Future<void> _saveMessagesForSession(
    String sessionId,
    List<ChatMessage> messages,
  ) async {
    final session = _sessionForId(sessionId);
    if (session == null) return;

    final updatedSession = session.copyWith(
      messages: messages,
      title: _deriveTitle(messages),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _replaceSession(updatedSession);
    });

    await _persistChats();
  }

  Future<void> _handleSend() async {
    if (_isInitializing || _isLoading) return;

    final userQuery = _chatController.text.trim();
    if (userQuery.isEmpty) return;

    final sessionId = _activeSession.id;
    final shouldFollowUserMessage = _isNearBottom;
    _userScrolledDuringRequest = false;

    final pendingMessages = [
      ..._messages,
      ChatMessage(
        text: userQuery,
        isUser: true,
      ),
    ];

    setState(() {
      _replaceSession(
        _activeSession.copyWith(
          messages: pendingMessages,
          title: _deriveTitle(pendingMessages),
          updatedAt: DateTime.now(),
        ),
      );
      _chatController.clear();
      _isLoading = true;
    });

    _scrollToBottomIf(shouldFollowUserMessage);
    await _persistChats();

    try {
      final response = await _apiService.getRAGResponse(userQuery);

      await _saveMessagesForSession(sessionId, [
        ...pendingMessages,
        ChatMessage(
          text: response,
          isUser: false,
          source: 'UniGuide',
        ),
      ]);
    } catch (error) {
      await _saveMessagesForSession(sessionId, [
        ...pendingMessages,
        ChatMessage(
          text: error.toString().replaceFirst('Exception: ', ''),
          isUser: false,
          source: 'System',
        ),
      ]);
    }

    if (!mounted) return;

    setState(() => _isLoading = false);
    if (_activeChatId == sessionId) _scrollToAssistantStart();
  }

  Future<void> _editUserMessage(int messageIndex) async {
    if (_isInitializing || _isLoading) return;
    final sessionId = _activeSession.id;
    final session = _sessionForId(sessionId);
    if (session == null ||
        messageIndex < 0 ||
        messageIndex >= session.messages.length) {
      return;
    }

    final message = session.messages[messageIndex];
    if (!message.isUser) return;

    final controller = TextEditingController(text: message.text);
    final editedText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Update your message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted ||
        editedText == null ||
        editedText.isEmpty ||
        editedText == message.text.trim()) {
      return;
    }

    final editedMessages = [
      ...session.messages.take(messageIndex),
      ChatMessage(
        text: editedText,
        isUser: true,
        timestamp: message.timestamp,
      ),
    ];

    _userScrolledDuringRequest = false;
    setState(() {
      _replaceSession(
        session.copyWith(
          messages: editedMessages,
          title: _deriveTitle(editedMessages),
          updatedAt: DateTime.now(),
        ),
      );
      _isLoading = true;
    });
    await _persistChats();

    try {
      final response = await _apiService.getRAGResponse(editedText);
      await _saveMessagesForSession(sessionId, [
        ...editedMessages,
        ChatMessage(text: response, isUser: false, source: 'UniGuide'),
      ]);
    } catch (error) {
      await _saveMessagesForSession(sessionId, [
        ...editedMessages,
        ChatMessage(
          text: error.toString().replaceFirst('Exception: ', ''),
          isUser: false,
          source: 'System',
        ),
      ]);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (_activeChatId == sessionId) _scrollToAssistantStart();
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 120;
  }

  void _handleMessageListScroll() {
    if (_isLoading) _userScrolledDuringRequest = true;
  }

  void _scrollToBottomIf(bool shouldScroll) {
    if (!shouldScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          _userScrolledDuringRequest) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToAssistantStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messageContext = _latestAssistantMessageKey.currentContext;
      if (!mounted || messageContext == null || _userScrolledDuringRequest) {
        return;
      }
      Scrollable.ensureVisible(
        messageContext,
        alignment: 0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _newChat() {
    final newSession = _createFreshSession();

    setState(() {
      _chatSessions = [newSession, ..._chatSessions];
      _activeChatId = newSession.id;
      _selectedIndex = 0;
      _chatController.clear();
    });

    _persistChats();
  }

  Future<void> _openChat(String chatId) async {
    setState(() {
      _activeChatId = chatId;
      _selectedIndex = 0;
    });

    await _persistChats();
  }

  Future<void> _deleteChat(String chatId) async {
    final deletingActiveChat = _activeChatId == chatId;

    setState(() {
      _chatSessions =
          _chatSessions.where((session) => session.id != chatId).toList();

      if (deletingActiveChat || _chatSessions.isEmpty) {
        final replacement = _createFreshSession();
        _chatSessions.insert(0, replacement);
        _activeChatId = replacement.id;
        _selectedIndex = 0;
      } else if (_activeChatId == chatId) {
        _activeChatId = _chatSessions.first.id;
      }
    });

    await _persistChats();
  }

  Future<void> _showRenameDialog(ChatSession session) async {
    final controller = TextEditingController(text: session.title);

    final updatedTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename chat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            inputFormatters: [
              LengthLimitingTextInputFormatter(42),
            ],
            decoration: const InputDecoration(
              hintText: 'Enter chat title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (updatedTitle == null || updatedTitle.isEmpty) return;

    setState(() {
      _replaceSession(
        session.copyWith(
          title: updatedTitle,
          updatedAt: DateTime.now(),
        ),
      );
    });

    await _persistChats();
  }

  String _formatSessionTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Updated just now';
    }
    if (difference.inHours < 1) {
      return 'Updated ${difference.inMinutes} min ago';
    }
    if (difference.inDays < 1) {
      return 'Updated ${difference.inHours} hr ago';
    }
    if (difference.inDays == 1) {
      return 'Updated yesterday';
    }

    return 'Updated ${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 760;
    final theme = Theme.of(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _prepareFreshChatLanding();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.sidebar,
          title: Row(
            children: [
              const UniGuideLogo(size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('UniGuide'),
                    Text(
                      _selectedIndex == 0
                          ? 'Study assistant for books, notes, and PYQs'
                          : 'Browse academic resources quickly',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'New Chat',
              onPressed: _newChat,
            ),
          ],
        ),
        drawer: isLargeScreen ? null : _buildDrawer(),
        bottomNavigationBar:
            isLargeScreen ? null : _buildMobileNavigation(theme),
        body: Row(
          children: [
            if (isLargeScreen) _buildSidebar(theme),
            Expanded(
              child: _isInitializing
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    return Container(
      width: 278,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.surface, AppColors.sidebar],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const UniGuideLogo(size: 44),
                ),
                const SizedBox(height: 14),
                Text(
                  'Workspace',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'UniGuide',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search your syllabus, open resources, and continue studying from one place.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.botText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final selected = index == _selectedIndex;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected ? AppColors.border : Colors.transparent,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ListTile(
                    selected: selected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent.withValues(alpha: 0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        selected ? item.selectedIcon : item.icon,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.botText,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.accent,
                          )
                        : null,
                    onTap: () => setState(() => _selectedIndex = index),
                  ),
                );
              },
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version $_appVersion',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Frontend refreshed with a cleaner chat workflow and copy-ready answers.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildChatUI();
      case 1:
        return const BranchScreen(category: 'books');
      case 2:
        return const BranchScreen(category: 'pyqs');
      case 3:
        return const BranchScreen(category: 'notes');
      case 4:
        return _buildHistoryView();
      default:
        return _buildChatUI();
    }
  }

  Widget _buildChatUI() {
    final theme = Theme.of(context);
    final isComposing = _chatController.text.trim().isNotEmpty;
    final isEmptyConversation = _messages.isEmpty;
    final showWelcomePanel = isEmptyConversation && !isComposing;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 640 ? 16.0 : 20.0;

    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: ChatMessageList(
                          messages: _messages,
                          scrollController: _scrollController,
                          isLoading: _isLoading,
                          onEditUserMessage: _editUserMessage,
                          latestAssistantMessageKey: _latestAssistantMessageKey,
                          onUserScroll: _handleMessageListScroll,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: showWelcomePanel
                          ? IgnorePointer(
                              ignoring: false,
                              key: const ValueKey('welcome-panel'),
                              child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  20,
                                  horizontalPadding,
                                  20,
                                ),
                                child: _buildWelcomePanel(theme),
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('no-welcome'),
                            ),
                    ),
                  ],
                ),
              ),
              ChatInputField(
                controller: _chatController,
                onSend: _handleSend,
                isLoading: _isLoading,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePanel(ThemeData theme) {
    final width = MediaQuery.of(context).size.width;
    final panelMaxWidth = width < 700 ? width : 620.0;
    final panelPadding = width < 600 ? 10.0 : 18.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: panelMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: panelPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _buildWelcomeAnimation(theme),
              ),
              Text(
                'Hello, UniGuide',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.heading,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ask anything from your syllabus and I will help you revise faster.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.botText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Start typing below to begin a new chat.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeAnimation(ThemeData theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0.09),
                  AppColors.primary.withValues(alpha: 0),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: value * 0.25,
                  child: Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.32),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: -value * 0.18,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.surface,
                        AppColors.accent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const UniGuideLogo(size: 72),
                ),
                Positioned(
                  top: 32,
                  right: 34,
                  child: _buildSparkDot(AppColors.keyTerm, 16),
                ),
                Positioned(
                  left: 28,
                  bottom: 42,
                  child: _buildSparkDot(AppColors.accent, 12),
                ),
                Positioned(
                  right: 48,
                  bottom: 28,
                  child: _buildSparkDot(AppColors.userText, 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSparkDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (_showHistoryRetentionNotice)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 820),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only your last $kMaxStoredChats chats are saved. '
                      'Older ones are deleted automatically.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(
                      () => _showHistoryRetentionNotice = false,
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _chatSessions.isEmpty
              ? const Center(
                  child: Text('Your previous chats will appear here.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _chatSessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final session = _chatSessions[index];
                    final isActive = session.id == _activeChatId;

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            title: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.previewText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatSessionTime(session.updatedAt),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: isActive
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'open') {
                                  _openChat(session.id);
                                } else if (value == 'rename') {
                                  _showRenameDialog(session);
                                } else if (value == 'delete') {
                                  _deleteChat(session.id);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Text('Open'),
                                ),
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                            onTap: () => _openChat(session.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(child: Text('UniGuide')),
          _drawerItem('Chat', 0),
          _drawerItem('Books', 1),
          _drawerItem('PYQs', 2),
          _drawerItem('Notes', 3),
          _drawerItem('History', 4),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('App Version: $_appVersion'),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(String title, int index) {
    return ListTile(
      title: Text(title),
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildMobileNavigation(ThemeData theme) {
    return NavigationBar(
      height: 78,
      elevation: 0,
      backgroundColor: AppColors.sidebar,
      indicatorColor: AppColors.accent.withValues(alpha: 0.12),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      destinations: _navItems.map((item) {
        final index = _navItems.indexOf(item);
        final selected = index == _selectedIndex;

        return NavigationDestination(
          icon: Icon(item.icon, color: AppColors.muted),
          selectedIcon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              item.selectedIcon,
              color: AppColors.accent,
            ),
          ),
          label: item.label,
          tooltip: selected ? '${item.label} selected' : item.label,
        );
      }).toList(),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
