import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import 'auth_providers.dart';
import 'auth_controller.dart';
import 'auth_messages.dart';

class AccessPage extends ConsumerWidget {
  const AccessPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final available = ref.watch(authRepositoryProvider) != null;
    final action = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.appName,
                    style: theme.textTheme.titleLarge!.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    header: true,
                    child: Text(
                      strings.accessTitle,
                      style: theme.textTheme.displaySmall!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.accessDescription,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.people_outline, size: 18),
                        label: Text(strings.community),
                      ),
                      Chip(
                        avatar: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text(strings.recipes),
                      ),
                      Chip(
                        avatar: const Icon(Icons.restaurant_outlined, size: 18),
                        label: Text(strings.cookToday),
                      ),
                      Chip(
                        avatar: const Icon(Icons.checklist, size: 18),
                        label: Text(strings.shopping),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(strings.accessRequired),
                  const SizedBox(height: 8),
                  if (!available) Text(strings.accessPending),
                  if (available) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: action.busy
                          ? null
                          : () => context.push('/access/login'),
                      child: Text(strings.signIn),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: action.busy
                          ? null
                          : () => context.push('/access/register'),
                      child: Text(strings.signUp),
                    ),
                  ],
                  if (action.failure != null)
                    Text(authFailureMessage(strings, action.failure!)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.push('/access/status'),
                    icon: const Icon(Icons.info_outline),
                    label: Text(strings.accessStatusAction),
                  ),
                  const SizedBox(height: 24),
                  Text(strings.tagline, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
