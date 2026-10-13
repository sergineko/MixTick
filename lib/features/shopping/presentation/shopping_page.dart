import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/feature_placeholder.dart';

class ShoppingPage extends StatelessWidget {
  const ShoppingPage({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return FeaturePlaceholder(
      title: strings.shoppingTitle,
      description: strings.shoppingDescription,
      icon: Icons.checklist_outlined,
    );
  }
}
