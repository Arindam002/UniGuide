import 'package:flutter/material.dart';

import '../features/chat/data/message_model.dart';
import '../features/chat/ui/widgets/chat_message_list.dart';
import '../features/chat/ui/widgets/chat_input_field.dart';
import '../screens/branch/branch_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/history_screen.dart';
import '../services/api/chat_api_service.dart';
import '../services/storage/session_service.dart';

class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({super.key});

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  int _selectedIndex = 0;

  bool _isLoggedIn = false;
  String _studentName = "Guest";
  final String _appVersion = "v1.0.0";

  final ChatApiService _chatApiService =
      ChatApiService(baseUrl: "http://10.199.157.23:5000");

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFF0D47A1);
  final Color _surfaceColor = const Color(0xFFF3F6FB);
  final Color _railColor = const Color(0xFFE3ECF8);
  final Color _selectedColor = const Color(0xFF0B3D91);
  final Color _unselectedColor = const Color(0xFF37474F);

  List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hello! I'm UniGuide 👋\nAsk me anything from your syllabus 📚",
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final studentId = await SessionService.getStudentId();

    if (!mounted) return;

    setState(() {
      _isLoggedIn = studentId != null;
      _studentName = _isLoggedIn ? "Student" : "Guest";
    });
  }

  Future<void> _openLoginScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );

    await _loadSession();
  }

  Future<void> _openSignupScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SignupScreen(),
      ),
    );

    await _loadSession();
  }

  Future<void> _handleLogout() async {
    await SessionService.logout();

    if (!mounted) return;

    setState(() {
      _isLoggedIn = false;
      _studentName = "Guest";
      _selectedIndex = 0;
    });
  }

  Future<void> _handleSend() async {
    if (_chatController.text.trim().isEmpty || _isLoading) return;

    final userQuery = _chatController.text.trim();

    setState(() {
      _messages.add(ChatMessage(text: userQuery, isUser: true));
      _chatController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final result = await _chatApiService.sendMessage(userQuery);
      final answer = result["answer"] ?? "No response received.";

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: answer,
            isUser: false,
            source: "RAG",
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: "⚠️ Unable to connect to backend",
            isUser: false,
          ),
        );
      });
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    _scrollToBottom();
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
    setState(() {
      _messages = [
        ChatMessage(
          text: "What's on your mind today? :)",
          isUser: false,
        ),
      ];
      _selectedIndex = 0;
    });
  }

  Future<void> _onRailDestinationSelected(int index) async {
    final int loginIndex = 5;
    final int signupIndex = 6;

    if (_isLoggedIn) {
      if (index == 5) {
        await _handleLogout();
        return;
      }
    } else {
      if (index == loginIndex) {
        await _openLoginScreen();
        return;
      }
      if (index == signupIndex) {
        await _openSignupScreen();
        return;
      }
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        title: Text(
          _isLoggedIn ? _studentName : "UniGuide",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: "New Chat",
            onPressed: _newChat,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _studentName.isNotEmpty ? _studentName[0].toUpperCase() : "G",
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: isLargeScreen ? null : _buildDrawer(),
      body: Row(
        children: [
          if (isLargeScreen)
            Container(
              color: _railColor,
              child: NavigationRail(
                backgroundColor: _railColor,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onRailDestinationSelected,
                labelType: NavigationRailLabelType.all,
                selectedIconTheme: IconThemeData(color: _selectedColor),
                unselectedIconTheme: IconThemeData(color: _unselectedColor),
                selectedLabelTextStyle: TextStyle(
                  color: _selectedColor,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: _unselectedColor,
                  fontWeight: FontWeight.w600,
                ),
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon: Icon(Icons.chat_bubble),
                    label: Text("Chat"),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: Text("Books"),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.quiz_outlined),
                    selectedIcon: Icon(Icons.quiz),
                    label: Text("PYQs"),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.sticky_note_2_outlined),
                    selectedIcon: Icon(Icons.sticky_note_2),
                    label: Text("Notes"),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.history),
                    selectedIcon: Icon(Icons.history),
                    label: Text("History"),
                  ),
                  if (_isLoggedIn)
                    const NavigationRailDestination(
                      icon: Icon(Icons.logout),
                      selectedIcon: Icon(Icons.logout),
                      label: Text("Logout"),
                    ),
                  if (!_isLoggedIn)
                    const NavigationRailDestination(
                      icon: Icon(Icons.login),
                      selectedIcon: Icon(Icons.login),
                      label: Text("Login"),
                    ),
                  if (!_isLoggedIn)
                    const NavigationRailDestination(
                      icon: Icon(Icons.person_add_alt_1_outlined),
                      selectedIcon: Icon(Icons.person_add_alt_1),
                      label: Text("Sign Up"),
                    ),
                ],
              ),
            ),
          VerticalDivider(width: 1, color: Colors.blueGrey.shade200),
          Expanded(
            child: _buildMainContent(),
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
        return const HistoryScreen();
      default:
        return _buildChatUI();
    }
  }

  Widget _buildChatUI() {
    return Container(
      color: _surfaceColor,
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: ChatMessageList(
                messages: _messages,
                isLoading: _isLoading,
                scrollController: _scrollController,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.blueGrey.shade100),
              ),
            ),
            child: ChatInputField(
              controller: _chatController,
              onSend: _handleSend,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: _primaryColor,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                _studentName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _drawerItem("Chat", 0, Icons.chat_bubble_outline),
          _drawerItem("Books", 1, Icons.menu_book_outlined),
          _drawerItem("PYQs", 2, Icons.quiz_outlined),
          _drawerItem("Notes", 3, Icons.sticky_note_2_outlined),
          _drawerItem("History", 4, Icons.history),
          if (!_isLoggedIn)
            _drawerActionItem("Login", Icons.login, _openLoginScreen),
          if (!_isLoggedIn)
            _drawerActionItem(
              "Sign Up",
              Icons.person_add_alt_1_outlined,
              _openSignupScreen,
            ),
          if (_isLoggedIn)
            _drawerActionItem("Logout", Icons.logout, _handleLogout),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              "App Version: $_appVersion",
              style: TextStyle(
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(String title, int index, IconData icon) {
    final bool isSelected = _selectedIndex == index;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? _selectedColor : _unselectedColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? _selectedColor : _unselectedColor,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      tileColor: isSelected ? _railColor : null,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _drawerActionItem(
    String title,
    IconData icon,
    Future<void> Function() onTapAction,
  ) {
    return ListTile(
      leading: Icon(icon, color: _unselectedColor),
      title: Text(
        title,
        style: TextStyle(
          color: _unselectedColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () async {
        Navigator.pop(context);
        await onTapAction();
      },
    );
  }
}