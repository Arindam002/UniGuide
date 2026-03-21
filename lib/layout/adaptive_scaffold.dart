import 'package:flutter/material.dart';
import '../features/chat/data/message_model.dart';
import '../features/chat/ui/widgets/chat_message_list.dart';
import '../features/chat/ui/widgets/chat_input_field.dart';
import '../features/chat/data/api_service.dart';
import '../screens/branch/branch_screen.dart';

class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({super.key});

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  int _selectedIndex = 0;

  bool _isLoggedIn = false;
  String _studentName = "Guest";
  String _appVersion = "v1.0.0";

  final ApiService _apiService = ApiService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;

  List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hello! I'm UniGuide 👋\nAsk me anything from your syllabus 📚",
      isUser: false,
    ),
  ];

  Future<void> _handleSend() async {
    if (_chatController.text.trim().isEmpty) return;

    String userQuery = _chatController.text;

    setState(() {
      _messages.add(ChatMessage(text: userQuery, isUser: true));
      _chatController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = await _apiService.getRAGResponse(userQuery);

      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          source: "RAG",
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "⚠️ Unable to connect to backend",
          isUser: false,
        ));
      });
    }

    setState(() => _isLoading = false);
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
          text: "New chat started 🚀",
          isUser: false,
        ),
      ];
    });
  }

  void _toggleLogin() {
    setState(() {
      _isLoggedIn = !_isLoggedIn;
      _studentName = _isLoggedIn ? "Arindam" : "Guest";
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoggedIn ? _studentName : "UniGuide"),
        actions: [
          TextButton(
            onPressed: _toggleLogin,
            child: Text(
              _isLoggedIn ? "Logout" : "Login",
              style: const TextStyle(color: Colors.blue),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "New Chat",
            onPressed: _newChat,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Text(
                _studentName[0],
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      drawer: isLargeScreen ? null : _buildDrawer(),
      body: Row(
        children: [
          if (isLargeScreen)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) {
                setState(() => _selectedIndex = i);
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: Text("Chat"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text("Books"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.quiz_outlined),
                  label: Text("PYQs"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.sticky_note_2_outlined),
                  label: Text("Notes"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history),
                  label: Text("History"),
                ),
              ],
            ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildMainContent()),
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
        return const Center(child: Text("🕓 History"));
      default:
        return _buildChatUI();
    }
  }

  Widget _buildChatUI() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.grey[100],
            child: ChatMessageList(
              messages: _messages,
              isLoading: _isLoading,
              scrollController: _scrollController,
            ),
          ),
        ),
        ChatInputField(
          controller: _chatController,
          onSend: _handleSend,
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(child: Text(_studentName)),
          _drawerItem("Chat", 0),
          _drawerItem("Books", 1),
          _drawerItem("PYQs", 2),
          _drawerItem("Notes", 3),
          _drawerItem("History", 4),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text("App Version: $_appVersion"),
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
}