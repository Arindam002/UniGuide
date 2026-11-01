import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../data/message_model.dart';

class ChatDiagramCard extends StatelessWidget {
  const ChatDiagramCard({
    super.key,
    required this.diagram,
  });

  final ChatDiagram diagram;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_tree_outlined,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  diagram.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.heading,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(diagram.steps.length, (index) {
            final step = diagram.steps[index];
            final isLast = index == diagram.steps.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${index + 1}.',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.heading,
                              ),
                            ),
                            if (step.detail.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                step.detail,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.botText,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                    ),
                ],
              ),
            );
          }),
          if ((diagram.footer ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              diagram.footer!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
