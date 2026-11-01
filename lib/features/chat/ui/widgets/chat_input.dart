import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

Widget buildChatInput() {
  return Container(
    padding: const EdgeInsets.all(12),
    child: TextField(
      decoration: InputDecoration(
        hintText: 'Ask UniGuide anything...',
        filled: true,
        fillColor: AppColors.surface,
        suffixIcon: IconButton(
          icon: const Icon(Icons.send),
          onPressed: () {},
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}
