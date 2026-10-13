import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/feature_placeholder.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return FeaturePlaceholder(
      title: strings.communityTitle,
      description: strings.communityDescription,
      icon: Icons.people_outline,
    );
  }
}
