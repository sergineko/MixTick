import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/auth_messages.dart';
import 'profile_providers.dart';
import 'profile_widgets.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final action = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.profile),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/community'),
        ),
      ),
      body: SafeArea(
        child: ref
            .watch(ownProfileProvider)
            .when(
              skipLoadingOnRefresh: false,
              loading: () => AppLoadingState(label: strings.loadingProfile),
              error: (error, _) => AppErrorState(
                message: profileErrorMessage(strings, error),
                actionLabel: strings.retry,
                onAction: () => ref.invalidate(ownProfileProvider),
              ),
              data: (profile) => Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: ProfileAvatar(path: profile?.avatarPath)),
                        const SizedBox(height: 16),
                        if (profile == null)
                          Text(
                            strings.completeProfile,
                            style: Theme.of(context).textTheme.headlineSmall,
                          )
                        else ...[
                          Text(
                            profile.displayName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            '@${profile.username}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: action.busy
                              ? null
                              : () => context.push('/profile/edit'),
                          child: Text(
                            profile == null
                                ? strings.createProfile
                                : strings.editProfile,
                          ),
                        ),
                        if (profile != null)
                          TextButton(
                            onPressed: action.busy
                                ? null
                                : () => context.push(
                                    '/people/${profile.username}',
                                  ),
                            child: Text(strings.viewPublicProfile),
                          ),
                        const Divider(height: 48),
                        OutlinedButton(
                          onPressed: action.busy
                              ? null
                              : () => context.push('/profile/find'),
                          child: Text(strings.findProfile),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          strings.account,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(strings.privateEmailLabel),
                        Text(
                          ref.watch(authRepositoryProvider)?.currentEmail ??
                              strings.emailUnavailable,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: action.busy
                              ? null
                              : () => context.push('/account/password'),
                          child: Text(strings.changePassword),
                        ),
                        TextButton(
                          onPressed: action.busy
                              ? null
                              : () async {
                                  await ref
                                      .read(authControllerProvider.notifier)
                                      .execute((repo) => repo.signOut());
                                },
                          child: Text(
                            action.busy ? strings.processing : strings.signOut,
                          ),
                        ),
                        TextButton.icon(
                          key: const ValueKey('account-deletion'),
                          onPressed: action.busy
                              ? null
                              : () => context.push('/account/delete'),
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: Text(strings.deleteAccount),
                        ),
                        if (action.failure != null)
                          Text(authFailureMessage(strings, action.failure!)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
