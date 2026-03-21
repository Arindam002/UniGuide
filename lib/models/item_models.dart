class PdfFileItem {
  final String name;
  final String filePath;

  PdfFileItem({
    required this.name,
    required this.filePath,
  });

  factory PdfFileItem.fromJson(Map<String, dynamic> json) {
    return PdfFileItem(
      name: json['name'] ?? '',
      filePath: json['file_path'] ?? '',
    );
  }
}