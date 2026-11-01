import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../models/item_models.dart';

class ItemsService {
  static const String itemsPath = '/items';

  static Future<List<String>> _getStringList(Uri uri, String key) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load $key (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded[key] is! List) {
      throw FormatException('Invalid $key response from backend');
    }

    final values = decoded[key] as List;
    if (values.any((value) => value is! String)) {
      throw FormatException('Invalid values in $key response');
    }

    return List<String>.from(values);
  }

  static Future<List<String>> getBranches(String category) async {
    final uri = Uri.http(AppConfig.apiHost, '$itemsPath/branches', {
      'category': category,
    });

    return _getStringList(uri, 'branches');
  }

  static Future<List<String>> getSemesters({
    required String category,
    required String branch,
  }) async {
    final uri = Uri.http(AppConfig.apiHost, '$itemsPath/semesters', {
      'category': category,
      'branch': branch,
    });

    return _getStringList(uri, 'semesters');
  }

  static Future<List<String>> getSubjects({
    required String category,
    required String branch,
    required String semester,
  }) async {
    final uri = Uri.http(AppConfig.apiHost, '$itemsPath/subjects', {
      'category': category,
      'branch': branch,
      'semester': semester,
    });

    return _getStringList(uri, 'subjects');
  }

  static Future<List<PdfFileItem>> getFiles({
    required String category,
    required String branch,
    required String semester,
    required String subject,
  }) async {
    final uri = Uri.http(AppConfig.apiHost, '$itemsPath/files', {
      'category': category,
      'branch': branch,
      'semester': semester,
      'subject': subject,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['files'] is! List) {
        throw const FormatException('Invalid files response from backend');
      }
      final files = data['files'] as List;
      if (files.any((file) => file is! Map)) {
        throw const FormatException('Invalid file entry in backend response');
      }
      return files
          .map(
            (file) => PdfFileItem.fromJson(
              Map<String, dynamic>.from(file as Map),
            ),
          )
          .toList();
    }

    throw Exception(
      'Failed to load files (${response.statusCode}): ${response.body}',
    );
  }

  static String getViewUrl(String filePath) {
    return Uri.http(AppConfig.apiHost, '$itemsPath/view', {
      'file_path': filePath,
    }).toString();
  }

  static String getDownloadUrl(String filePath) {
    return Uri.http(AppConfig.apiHost, '$itemsPath/download', {
      'file_path': filePath,
    }).toString();
  }
}
