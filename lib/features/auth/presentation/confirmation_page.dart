import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';

class ConfirmationPage extends ConsumerStatefulWidget {
  const ConfirmationPage({super.key});
  @override
  ConsumerState<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends ConsumerState<ConfirmationPage> {
  bool _resent = false;
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final action = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(s.confirmEmail)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(s.confirmationSent),
                  if (_resent)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(s.confirmationSent),
                    ),
                  if (action.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(authFailureMessage(s, action.failure!)),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: action.busy
                        ? null
                        : () => context.go('/access/login'),
                    child: Text(s.signIn),
                  ),
                  if (controller.confirmationEmail != null)
                    TextButton(
                      onPressed: action.busy
                          ? null
                          : () async {
                              final success = await controller.execute(
                                (repo) => repo.resendConfirmation(
                                  controller.confirmationEmail!,
                                ),
                              );
                              if (mounted && success) {
                                setState(() => _resent = true);
                              }
                            },
                      child: Text(s.resendEmail),
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
