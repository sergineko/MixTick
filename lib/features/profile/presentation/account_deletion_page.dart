import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/network/supabase_bootstrap.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../recipes/domain/recipe.dart';
import '../data/supabase_account_deletion_repository.dart';
import '../domain/account_deletion_repository.dart';

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository?>((
  ref,
) {
  final client = ref.watch(backendProvider).client;
  return client == null ? null : SupabaseAccountDeletionRepository(client);
});

class AccountDeletionPage extends ConsumerStatefulWidget {
  const AccountDeletionPage({super.key});
  @override
  ConsumerState<AccountDeletionPage> createState() =>
      _AccountDeletionPageState();
}

class _AccountDeletionPageState extends ConsumerState<AccountDeletionPage> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  final requestId = newRecipeRequestId();
  bool agreed = false, busy = false;
  AccountDeletionFailureCode? failure;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy ||
        !agreed ||
        confirmation.text != 'ELIMINAR' ||
        password.text.isEmpty) {
      return;
    }
    final repo = ref.read(accountDeletionRepositoryProvider);
    final actor = ref.read(authSessionProvider).value?.userId;
    if (repo == null || actor == null) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await repo.request(password.text, requestId);
      if (!mounted || ref.read(authSessionProvider).value?.userId != actor) {
        return;
      }
      password.clear();
      confirmation.clear();
      final messenger = ScaffoldMessenger.of(context);
      final message = AppLocalizations.of(context).accountDeletionAccepted;
      // The accepted server job survives logout, process exit and offline mode.
      try {
        await ref.read(authRepositoryProvider)?.signOut();
      } catch (_) {}
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (mounted && ref.read(authSessionProvider).value?.userId == actor) {
        setState(() {
          busy = false;
          failure = error is AccountDeletionFailure
              ? error.code
              : AccountDeletionFailureCode.unexpected;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final message = switch (failure) {
      AccountDeletionFailureCode.credentials =>
        strings.accountDeletionCredentials,
      AccountDeletionFailureCode.forbidden => strings.accountDeletionSession,
      null => null,
      _ => strings.accountDeletionRetry,
    };
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(strings.deleteAccount)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(strings.accountDeletionConsequences),
              const SizedBox(height: 16),
              Text(strings.accountDeletionLists),
              const SizedBox(height: 16),
              CheckboxListTile(
                key: const ValueKey('delete-account-agree'),
                contentPadding: EdgeInsets.zero,
                value: agreed,
                onChanged: busy
                    ? null
                    : (value) => setState(() => agreed = value ?? false),
                title: Text(strings.accountDeletionConsent),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('delete-account-password'),
                controller: password,
                obscureText: true,
                enabled: !busy,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: strings.password),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('delete-account-confirm'),
                controller: confirmation,
                enabled: !busy,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: strings.accountDeletionType,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('delete-account-submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed:
                    busy ||
                        !agreed ||
                        password.text.isEmpty ||
                        confirmation.text != 'ELIMINAR'
                    ? null
                    : submit,
                icon: const Icon(Icons.delete_forever),
                label: Text(busy ? strings.processing : strings.deleteAccount),
              ),
              if (busy)
                Semantics(
                  liveRegion: true,
                  child: Text(strings.accountDeletionProcessing),
                ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: Text(message)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
