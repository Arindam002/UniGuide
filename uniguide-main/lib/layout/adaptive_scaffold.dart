import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/chat/data/api_service.dart';
import '../features/chat/data/chat_storage_service.dart';
import '../features/chat/data/message_model.dart';
import '../features/chat/ui/widgets/chat_input_field.dart';
import '../features/chat/ui/widgets/chat_message_list.dart';
import '../screens/branch/branch_screen.dart';

class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({super.key});

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isInitializing = true;

  String _studentName = 'Guest';
  ChatUser _currentUser = const ChatUser.guest();
  final String _appVersion = 'v1.1.0';

  final ApiService _apiService = ApiService();
  final ChatStorageService _chatStorageService = ChatStorageService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatSession> _chatSessions = [];
  String? _activeChatId;

  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Chat',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
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
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  Future<void> _loadChats() async {
    final currentUser = await _chatStorageService.loadCurrentUser();
    final sessions = await _chatStorageService.loadSessions(
      userId: currentUser.id,
    );
    final activeChatId = await _chatStorageService.loadActiveChatId(
      userId: currentUser.id,
    );

    if (!mounted) return;

    setState(() {
      _currentUser = currentUser;
      _isLoggedIn = !currentUser.isGuest;
      _studentName = currentUser.name;
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
        _activeChatId =
            _chatSessions.any((session) => session.id == activeChatId)
                ? activeChatId
                : landingSession.id;
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
    return _chatStorageService.saveSessions(
      sessions: _chatSessions,
      activeChatId: _activeChatId,
      userId: _currentUser.id,
    );
  }

  void _replaceSession(ChatSession updatedSession) {
    _chatSessions = _chatSessions
        .map((session) =>
            session.id == updatedSession.id ? updatedSession : session)
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
    if (title.isEmpty) {
      return 'New chat';
    }
    if (title.length <= 42) {
      return title;
    }
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

    await _persistChats();
    // Scroll once when the user sends a new message. Avoid auto-scrolling
    // during AI streaming/typing to keep reading position stable.
    _scrollToBottom();

    try {
      final response = await _apiService.getRAGResponse(userQuery);
      await _saveMessagesForSession(sessionId, [
        ...pendingMessages,
        ChatMessage(
          text: response.answer,
          isUser: false,
          source: response.sources.isEmpty
              ? 'UniGuide'
              : 'UniGuide - ${response.sources.first}',
          diagram:
              response.diagram?.hasContent ?? false ? response.diagram : null,
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
  }

  Future<void> _editUserMessage(int messageIndex) async {
    if (_isInitializing || _isLoading) return;
    if (messageIndex < 0 || messageIndex >= _messages.length) return;

    final message = _messages[messageIndex];
    if (!message.isUser) return;

    final controller = TextEditingController(text: message.text);
    final editedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Update your message',
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

    if (editedText == null ||
        editedText.isEmpty ||
        editedText == message.text.trim()) {
      return;
    }

    final sessionId = _activeSession.id;
    final retainedMessages = _messages.take(messageIndex).toList();
    final editedMessages = [
      ...retainedMessages,
      ChatMessage(
        text: editedText,
        isUser: true,
        timestamp: message.timestamp,
      ),
    ];

    setState(() {
      _replaceSession(
        _activeSession.copyWith(
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
        ChatMessage(
          text: response.answer,
          isUser: false,
          source: response.sources.isEmpty
              ? 'UniGuide'
              : 'UniGuide - ${response.sources.first}',
          diagram:
              response.diagram?.hasContent ?? false ? response.diagram : null,
        ),
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
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
    if (_chatSessions.length == 1) {
      final replacement = _createFreshSession();
      setState(() {
        _chatSessions = [replacement];
        _activeChatId = replacement.id;
        _selectedIndex = 0;
      });
      await _persistChats();
      return;
    }

    setState(() {
      _chatSessions =
          _chatSessions.where((session) => session.id != chatId).toList();
      if (_activeChatId == chatId) {
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

  Future<void> _toggleLogin() async {
    if (_isLoggedIn) {
      await _persistChats();
      await _chatStorageService.logout();
      await _switchToUser(const ChatUser.guest());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out. Guest chats loaded.')),
      );
      return;
    }

    await _showLoginDialog();
  }

  Future<void> _showLoginDialog() async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();

    final credentials = await showDialog<_LoginCredentials>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Login name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                onSubmitted: (_) {
                  Navigator.pop(
                    context,
                    _LoginCredentials(
                      name: nameController.text,
                      password: passwordController.text,
                    ),
                  );
                },
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _LoginCredentials(
                    name: nameController.text,
                    password: passwordController.text,
                  ),
                );
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    passwordController.dispose();

    if (credentials == null) return;

    final result = await _chatStorageService.loginOrCreateUser(
      name: credentials.name,
      password: credentials.password,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (!result.success || result.user == null) return;

    await _persistChats();
    await _switchToUser(result.user!);
  }

  Future<void> _switchToUser(ChatUser user) async {
    final sessions = await _chatStorageService.loadSessions(userId: user.id);
    final activeChatId = await _chatStorageService.loadActiveChatId(
      userId: user.id,
    );

    if (!mounted) return;

    setState(() {
      _currentUser = user;
      _isLoggedIn = !user.isGuest;
      _studentName = user.name;
      if (sessions.isEmpty) {
        final initialSession = _createFreshSession();
        _chatSessions = [initialSession];
        _activeChatId = initialSession.id;
      } else {
        _chatSessions = List<ChatSession>.from(sessions)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final draftSession = _ensureDraftSession(_chatSessions);
        _chatSessions
          ..removeWhere((session) => session.id == draftSession.id)
          ..insert(0, draftSession);
        _activeChatId =
            _chatSessions.any((session) => session.id == activeChatId)
                ? activeChatId
                : draftSession.id;
      }
      _chatController.clear();
      _isLoading = false;
      _selectedIndex = 0;
    });

    await _chatStorageService.saveCurrentUser(user);
    await _persistChats();
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 760;
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        await _prepareFreshChatLanding();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF163A66),
                      Color(0xFF2C6CB2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2C6CB2).withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isLoggedIn ? _studentName : 'UniGuide'),
                    Text(
                      _selectedIndex == 0
                          ? 'Study assistant for books, notes, and PYQs'
                          : 'Browse academic resources quickly',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD9E1EC)),
              ),
              child: TextButton.icon(
                onPressed: _toggleLogin,
                icon: Icon(
                  _isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                  size: 16,
                  color: const Color(0xFF1B4D8C),
                ),
                label: Text(
                  _isLoggedIn ? 'Logout' : 'Login',
                  style: const TextStyle(color: Color(0xFF1B4D8C)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'New Chat',
              onPressed: _newChat,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF1B4D8C),
                child: Text(
                  _studentName[0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
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
        gradient: LinearGradient(
          colors: [
            Color(0xFFF2F7FC),
            Color(0xFFE8F0F8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          right: BorderSide(color: Color(0xFFD4DEE9)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF163A66),
                  Color(0xFF2C6CB2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF163A66).withValues(alpha: 0.18),
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
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Workspace',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'UniGuide',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search your syllabus, open resources, and continue studying from one place.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
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
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFDCE7F5)
                          : Colors.transparent,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF1B4D8C)
                                  .withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
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
                            ? const Color(0xFFE7F0FB)
                            : const Color(0xFFF3F6FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        selected ? item.selectedIcon : item.icon,
                        color: const Color(0xFF1B4D8C),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color: const Color(0xFF162132),
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Color(0xFF1B4D8C),
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
                      color: const Color(0xFF526173),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Frontend refreshed with a cleaner chat workflow and copy-ready answers.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5D6B7D),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF6F9FC),
            Color(0xFFEAF1F8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: _buildAmbientGlow(
              size: 220,
              colors: const [Color(0x552C6CB2), Color(0x1188B8F2)],
            ),
          ),
          Positioned(
            left: -70,
            top: 180,
            child: _buildAmbientGlow(
              size: 180,
              colors: const [Color(0x33A7D6FF), Color(0x00A7D6FF)],
            ),
          ),
          Positioned(
            right: -50,
            bottom: 120,
            child: _buildAmbientGlow(
              size: 160,
              colors: const [Color(0x22FFD280), Color(0x00FFD280)],
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ChatMessageList(
                      messages: _messages,
                      scrollController: _scrollController,
                      onEditUserMessage: _editUserMessage,
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
                          : const SizedBox.shrink(key: ValueKey('no-welcome')),
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

  Widget _buildAmbientGlow({
    required double size,
    required List<Color> colors,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
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
                  color: const Color(0xFF142033),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ask anything from your syllabus and I will help you revise faster.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF506073),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Start typing below to begin a new chat.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6A7788),
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
              gradient: const RadialGradient(
                colors: [
                  Color(0x66D9ECFF),
                  Color(0x22A7D6FF),
                  Color(0x00A7D6FF),
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
                        color: const Color(0x552C6CB2),
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
                        color: const Color(0x4488B8F2),
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
                        Color(0xFF163A66),
                        Color(0xFF2C6CB2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2C6CB2).withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                Positioned(
                  top: 32,
                  right: 34,
                  child: _buildSparkDot(const Color(0xFFFFD166), 16),
                ),
                Positioned(
                  left: 28,
                  bottom: 42,
                  child: _buildSparkDot(const Color(0xFF88B8F2), 12),
                ),
                Positioned(
                  right: 48,
                  bottom: 28,
                  child: _buildSparkDot(const Color(0xFF7EE081), 10),
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

    if (_chatSessions.isEmpty) {
      return const Center(
        child: Text('Your previous chats will appear here.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _chatSessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = _chatSessions[index];
        final isActive = session.id == _activeChatId;

        return Card(
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
                color: const Color(0xFF162132),
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
                      color: const Color(0xFF5D6B7D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatSessionTime(session.updatedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            leading: CircleAvatar(
              backgroundColor:
                  isActive ? const Color(0xFF1B4D8C) : const Color(0xFFE7F0FB),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: isActive ? Colors.white : const Color(0xFF1B4D8C),
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
                PopupMenuItem(value: 'open', child: Text('Open')),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            onTap: () => _openChat(session.id),
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(child: Text(_studentName)),
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
      backgroundColor: Colors.white.withValues(alpha: 0.98),
      indicatorColor: const Color(0xFFE7F0FB),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      destinations: _navItems.map((item) {
        final index = _navItems.indexOf(item);
        final selected = index == _selectedIndex;
        return NavigationDestination(
          icon: Icon(item.icon, color: const Color(0xFF617083)),
          selectedIcon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEBFB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.selectedIcon, color: const Color(0xFF1B4D8C)),
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

class _LoginCredentials {
  const _LoginCredentials({
    required this.name,
    required this.password,
  });

  final String name;
  final String password;
}
