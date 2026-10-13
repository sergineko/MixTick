import 'package:flutter/material.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../auth/presentation/session_scope.dart';
import 'community_browse.dart';

import 'package:go_router/go_router.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return SessionScope(
      child: CommunityBrowse(
        header: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.push('/community/blocked'),
            icon: const Icon(Icons.block),
            label: Text(strings.communityBlocked),
          ),
        ),
      ),
    );
  }
}
