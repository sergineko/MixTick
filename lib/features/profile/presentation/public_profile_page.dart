import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import 'profile_providers.dart';
import 'profile_widgets.dart';

class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({required this.username, super.key});
  final String username;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.publicProfile)),
      body: SafeArea(
        child: ref
            .watch(publicProfileProvider(username))
            .when(
              skipLoadingOnRefresh: false,
              loading: () => AppLoadingState(label: s.loadingProfile),
              error: (error, _) => AppErrorState(
                message: profileErrorMessage(s, error),
                actionLabel: s.retry,
                onAction: () => ref.invalidate(publicProfileProvider(username)),
              ),
              data: (profile) => Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: profile == null
                      ? Text(s.profileNotFound)
                      : Column(
                          children: [
                            ProfileAvatar(path: profile.avatarPath),
                            const SizedBox(height: 16),
                            Text(
                              profile.displayName,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('@${profile.username}'),
                          ],
                        ),
                ),
              ),
            ),
      ),
    );
  }
}
