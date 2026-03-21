import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_models.dart';

class ItemsService {
  static const String host = '10.199.157.23:5000';
  static const String itemsPath = '/items';

  static Future<List<String>> getBranches(String category) async {
    final uri = Uri.http(host, '$itemsPath/branches', {
      'category': category,
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['branches'] ?? []);
    } else {
      throw Exception(
        'Failed to load branches (${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<List<String>> getSemesters({
    required String category,
    required String branch,
  }) async {
    final uri = Uri.http(host, '$itemsPath/semesters', {
      'category': category,
      'branch': branch,
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['semesters'] ?? []);
    } else {
      throw Exception(
        'Failed to load semesters (${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<List<String>> getSubjects({
    required String category,
    required String branch,
    required String semester,
  }) async {
    final uri = Uri.http(host, '$itemsPath/subjects', {
      'category': category,
      'branch': branch,
      'semester': semester,
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['subjects'] ?? []);
    } else {
      throw Exception(
        'Failed to load subjects (${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<List<PdfFileItem>> getFiles({
    required String category,
    required String branch,
    required String semester,
    required String subject,
  }) async {
    final uri = Uri.http(host, '$itemsPath/files', {
      'category': category,
      'branch': branch,
      'semester': semester,
      'subject': subject,
    });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final files = data['files'] as List? ?? [];
      return files.map((e) => PdfFileItem.fromJson(e)).toList();
    } else {
      throw Exception(
        'Failed to load files (${response.statusCode}): ${response.body}',
      );
    }
  }

  static String getViewUrl(String filePath) {
    return Uri.http(host, '$itemsPath/view', {
      'file_path': filePath,
    }).toString();
  }

  static String getDownloadUrl(String filePath) {
    return Uri.http(host, '$itemsPath/download', {
      'file_path': filePath,
    }).toString();
  }
}