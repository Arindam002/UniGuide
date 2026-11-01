import 'package:flutter/material.dart';
import '../services/api/chat_api_service.dart';
import '../services/storage/session_service.dart';
import '../features/chat/data/message_model.dart';
import '../features/chat/ui/widgets/chat_message_list.dart';
import '../features/chat/ui/widgets/chat_input_field.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatApiService api =
      ChatApiService(baseUrl: "http://10.199.157.23:5000");

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> messages = [
    ChatMessage(
      text: "Hello! I'm UniGuide 👋\nAsk me anything from your syllabus 📚",
      isUser: false,
    ),
  ];

  bool isLoading = false;

  Future<void> sendMessage() async {
    final message = _controller.text.trim();

    if (message.isEmpty || isLoading) return;

    setState(() {
      messages.add(ChatMessage(text: message, isUser: true));
      _controller.clear();
      isLoading = true;
    });

    _scrollToBottom();

    try {
      final studentId = await SessionService.getStudentId();

      final response = await api.sendMessage(
        message,
        studentId: studentId,
      );

      final answer = response["answer"] ?? "No response";

      if (!mounted) return;

      setState(() {
        messages.add(
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
        messages.add(
          ChatMessage(
            text: "⚠️ Failed to connect to server",
            isUser: false,
          ),
        );
      });
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ChatMessageList(
            messages: messages,
            isLoading: isLoading,
            scrollController: _scrollController,
          ),
        ),
        ChatInputField(
          controller: _controller,
          onSend: sendMessage,
        ),
      ],
    );
  }
}