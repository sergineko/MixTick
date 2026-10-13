import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';

class SessionPage extends StatelessWidget {
  const SessionPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AppLoadingState(
        label: AppLocalizations.of(context).checkingSession,
      ),
    ),
  );
}
