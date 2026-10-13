import 'package:flutter/material.dart';

/// A network failure must be represented by AppErrorState, never empty data.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.footer,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    icon,
                    size: 36,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
              if (footer != null) ...[const SizedBox(height: 24), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(semanticsLabel: label),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    ),
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    title: message,
    message: '',
    icon: Icons.error_outline,
    footer: FilledButton(onPressed: onAction, child: Text(actionLabel)),
  );
}
