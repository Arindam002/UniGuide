import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/item_models.dart';
import '../../services/items_service.dart';

class FileListScreen extends StatefulWidget {
  final String category;
  final String branch;
  final String semester;
  final String subject;

  const FileListScreen({
    super.key,
    required this.category,
    required this.branch,
    required this.semester,
    required this.subject,
  });

  @override
  State<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  late Future<List<PdfFileItem>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = ItemsService.getFiles(
      category: widget.category,
      branch: widget.branch,
      semester: widget.semester,
      subject: widget.subject,
    );
  }

  Future<void> _openPdf(String filePath) async {
  final urlString = ItemsService.getViewUrl(filePath);
  final uri = Uri.parse(urlString);

  debugPrint('OPEN PDF URL: $urlString');

  final launched = await launchUrl(
    uri,
    mode: LaunchMode.platformDefault,
  );

  if (!launched && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open PDF\n$urlString')),
    );
  }
}

Future<void> _downloadPdf(String filePath) async {
  final urlString = ItemsService.getDownloadUrl(filePath);
  final uri = Uri.parse(urlString);

  debugPrint('DOWNLOAD PDF URL: $urlString');

  final launched = await launchUrl(
    uri,
    mode: LaunchMode.platformDefault,
  );

  if (!launched && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not download PDF\n$urlString')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject),
      ),
      body: FutureBuilder<List<PdfFileItem>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return const Center(child: Text('No PDF files found'));
          }

          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(file.name),
                  subtitle: Text(file.filePath),
                  onTap: () => _openPdf(file.filePath),
                  trailing: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () => _downloadPdf(file.filePath),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}