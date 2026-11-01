class PdfFileItem {
  final String name;
  final String filePath;

  PdfFileItem({
    required this.name,
    required this.filePath,
  });

  factory PdfFileItem.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final filePath = json['file_path'];
    if (name is! String || filePath is! String) {
      throw const FormatException('Invalid PDF file entry from backend');
    }

    return PdfFileItem(
      name: name,
      filePath: filePath,
    );
  }
}
