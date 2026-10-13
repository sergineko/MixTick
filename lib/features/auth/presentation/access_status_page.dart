import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/network/supabase_bootstrap.dart';
import '../../../core/widgets/app_states.dart';
import 'auth_providers.dart';

class AccessStatusPage extends ConsumerWidget {
  const AccessStatusPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final backend = ref.watch(backendProvider);
    final session = ref.watch(authSessionProvider);
    final message = session.hasError
        ? strings.sessionError
        : backend.status == BackendStatus.initialized
        ? strings.accessConfigured
        : strings.serviceUnavailable;
    return Scaffold(
      appBar: AppBar(title: Text(strings.accessStatusTitle)),
      body: SafeArea(
        child: AppErrorState(
          message: message,
          actionLabel: strings.backToAccess,
          onAction: () => context.go('/access'),
        ),
      ),
    );
  }
}
