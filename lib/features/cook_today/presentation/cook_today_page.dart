import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/feature_placeholder.dart';

class CookTodayPage extends StatelessWidget {
  const CookTodayPage({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return FeaturePlaceholder(
      title: strings.cookTodayTitle,
      description: strings.cookTodayDescription,
      notice: strings.cookTodayNotice,
      icon: Icons.restaurant_outlined,
    );
  }
}
