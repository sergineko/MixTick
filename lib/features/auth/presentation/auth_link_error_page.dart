import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../domain/auth_failure.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';
import 'auth_providers.dart';

class AuthLinkErrorPage extends ConsumerWidget {
  const AuthLinkErrorPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppLocalizations.of(context);
    final action = ref.watch(authControllerProvider);
    final authenticated = ref.watch(authSessionProvider).value != null;
    return Scaffold(
      appBar: AppBar(title: Text(s.accessStatusTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    authFailureMessage(
                      s,
                      action.failure ?? AuthFailureCode.invalidLink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: action.busy ? null : () => context.go('/access'),
                    child: Text(s.backToAccess),
                  ),
                  TextButton(
                    onPressed: action.busy
                        ? null
                        : () async {
                            if (authenticated) {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .execute((repo) => repo.signOut());
                            }
                            if (context.mounted) context.go('/access/recovery');
                          },
                    child: Text(
                      authenticated ? s.signOutAndRecover : s.recoverPassword,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
