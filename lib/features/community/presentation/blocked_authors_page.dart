import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import 'community_providers.dart';
import 'community_widgets.dart';

class BlockedAuthorsPage extends ConsumerWidget {
  const BlockedAuthorsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context),
        busy = ref.watch(socialActionsProvider).busy;
    return Scaffold(
      appBar: AppBar(title: Text(s.communityBlocked)),
      body: SafeArea(
        child: Column(
          children: [
            const SocialFeedback(),
            Expanded(
              child: ref
                  .watch(blockedAuthorsProvider)
                  .when(
                    skipLoadingOnRefresh: false,
                    loading: () => AppLoadingState(label: s.communityLoading),
                    error: (e, _) => AppErrorState(
                      message: communityError(s, e),
                      actionLabel: s.retry,
                      onAction: () => ref.invalidate(blockedAuthorsProvider),
                    ),
                    data: (ids) => ids.isEmpty
                        ? AppEmptyState(title: s.communityNoBlocks, message: '')
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: ids.length,
                            itemBuilder: (context, i) => Card(
                              child: ListTile(
                                isThreeLine: true,
                                title: Text(
                                  '${s.communityBlockedAccount} · ${ids[i].split('-').first}',
                                ),
                                subtitle: Text(s.communityBlockPrivacy),
                                trailing: IconButton(
                                  tooltip: s.communityUnblock,
                                  onPressed: busy
                                      ? null
                                      : () => ref
                                            .read(
                                              socialActionsProvider.notifier,
                                            )
                                            .run((r) => r.block(ids[i], false)),
                                  icon: const Icon(Icons.lock_open),
                                ),
                              ),
                            ),
                          ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
