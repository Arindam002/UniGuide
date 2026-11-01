import 'package:flutter/material.dart';
import '../../services/items_service.dart';
import 'subject_screen.dart';

class SemesterScreen extends StatefulWidget {
  final String category;
  final String branch;

  const SemesterScreen({
    super.key,
    required this.category,
    required this.branch,
  });

  @override
  State<SemesterScreen> createState() => _SemesterScreenState();
}

class _SemesterScreenState extends State<SemesterScreen> {
  late Future<List<String>> _semestersFuture;

  @override
  void initState() {
    super.initState();
    _semestersFuture = ItemsService.getSemesters(
      category: widget.category,
      branch: widget.branch,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.branch} - Semesters'),
      ),
      body: FutureBuilder<List<String>>(
        future: _semestersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final semesters = snapshot.data ?? [];

          if (semesters.isEmpty) {
            return const Center(child: Text('No semesters found'));
          }

          return ListView.builder(
            itemCount: semesters.length,
            itemBuilder: (context, index) {
              final semester = semesters[index];

              return ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(semester),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubjectScreen(
                        category: widget.category,
                        branch: widget.branch,
                        semester: semester,
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