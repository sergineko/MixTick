import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../shared/widgets/feature_placeholder.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.profile),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/community'),
        ),
      ),
      body: SafeArea(
        child: FeaturePlaceholder(
          title: strings.profile,
          description: strings.profileDescription,
          icon: Icons.person_outline,
        ),
      ),
    );
  }
}
