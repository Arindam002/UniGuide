import 'package:flutter/material.dart';
import '../../services/items_service.dart';
import 'semester_screen.dart';

class BranchScreen extends StatefulWidget {
  final String category;

  const BranchScreen({
    super.key,
    required this.category,
  });

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen> {
  late Future<List<String>> _branchesFuture;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  void _loadBranches() {
    _branchesFuture = ItemsService.getBranches(widget.category);
  }

  Future<void> _refreshBranches() async {
    setState(() {
      _loadBranches();
    });
    await _branchesFuture;
  }

  String _formatCategoryTitle(String category) {
    if (category.isEmpty) return 'Branches';
    return '${category[0].toUpperCase()}${category.substring(1)}';
  }

  String _formatBranchName(String branch) {
    return branch.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final categoryTitle = _formatCategoryTitle(widget.category);

    return Scaffold(
      appBar: AppBar(
        title: Text('$categoryTitle - Branches'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<String>>(
        future: _branchesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load branches',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _loadBranches();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final branches = snapshot.data ?? [];

          if (branches.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshBranches,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          size: 60,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No branches found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshBranches,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final branch = branches[index];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_tree,
                        color: Colors.blue,
                      ),
                    ),
                    title: Text(
                      _formatBranchName(branch),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text('Tap to view semesters'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SemesterScreen(
                            category: widget.category,
                            branch: branch,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}