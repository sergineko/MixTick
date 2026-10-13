import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';

class AccessPage extends StatelessWidget {
  const AccessPage({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
                  Text(strings.accessPending),
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
