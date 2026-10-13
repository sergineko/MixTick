import 'package:flutter/material.dart';

import '../../app/localization/generated/app_localizations.dart';
import '../../core/widgets/app_states.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    required this.title,
    required this.description,
    required this.icon,
    this.notice,
    super.key,
  });
  final String title;
  final String description;
  final IconData icon;
  final String? notice;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    title: title,
    message: description,
    icon: icon,
    footer: Column(
      children: [
        Chip(label: Text(AppLocalizations.of(context).comingSoon)),
        if (notice != null) ...[
          const SizedBox(height: 16),
          Text(notice!, textAlign: TextAlign.center),
        ],
      ],
    ),
  );
}
