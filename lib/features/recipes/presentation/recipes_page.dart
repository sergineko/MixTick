import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/feature_placeholder.dart';

class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return FeaturePlaceholder(
      title: strings.recipesTitle,
      description: strings.recipesDescription,
      notice: strings.recipesPrivacy,
      icon: Icons.menu_book_outlined,
    );
  }
}
