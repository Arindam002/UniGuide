import 'package:flutter/material.dart';
import '../services/api/history_api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryApiService historyApi =
      HistoryApiService(baseUrl: "http://10.199.157.23:5000");

  List<dynamic> history = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final data = await historyApi.fetchHistory();

      if (!mounted) return;

      setState(() {
        history = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await historyApi.deleteHistory(id);
      await loadHistory();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete history: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text("Error: $errorMessage"));
    }

    if (history.isEmpty) {
      return const Center(child: Text("No history found"));
    }

    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(item["query"] ?? "No query"),
            subtitle: Text(item["created_at"] ?? ""),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => deleteItem(item["id"]),
            ),
          ),
        );
      },
    );
  }
}