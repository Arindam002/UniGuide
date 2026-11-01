import 'package:flutter/material.dart';
import '../../services/items_service.dart';
import '../books/file_list_screen.dart';

class SubjectScreen extends StatefulWidget {
  final String category;
  final String branch;
  final String semester;

  const SubjectScreen({
    super.key,
    required this.category,
    required this.branch,
    required this.semester,
  });

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  late Future<List<String>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = ItemsService.getSubjects(
      category: widget.category,
      branch: widget.branch,
      semester: widget.semester,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.semester} - Subjects'),
      ),
      body: FutureBuilder<List<String>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final subjects = snapshot.data ?? [];

          if (subjects.isEmpty) {
            return const Center(child: Text('No subjects found'));
          }

          return ListView.builder(
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];

              return ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(subject),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FileListScreen(
                        category: widget.category,
                        branch: widget.branch,
                        semester: widget.semester,
                        subject: subject,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}