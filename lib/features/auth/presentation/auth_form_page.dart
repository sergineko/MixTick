import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../domain/auth_validation.dart';
import 'auth_controller.dart';
import 'auth_providers.dart';
import 'auth_messages.dart';

enum AuthFormMode { signIn, signUp, recovery, password }

class AuthFormPage extends ConsumerStatefulWidget {
  const AuthFormPage({required this.mode, super.key});
  final AuthFormMode mode;
  @override
  ConsumerState<AuthFormPage> createState() => _AuthFormPageState();
}

class _AuthFormPageState extends ConsumerState<AuthFormPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _hidden = true;
  bool _sent = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    final email = _email.text.trim();
    final passwordValue = _password.text;
    var confirmation = false;
    final success = await controller.execute((repo) async {
      switch (widget.mode) {
        case AuthFormMode.signIn:
          await repo.signIn(email, passwordValue);
        case AuthFormMode.signUp:
          confirmation = await repo.signUp(email, passwordValue);
          controller.confirmationEmail = email;
        case AuthFormMode.recovery:
          await repo.requestPasswordReset(email);
        case AuthFormMode.password:
          await repo.updatePassword(passwordValue);
      }
    });
    if (!mounted || !success) return;
    _password.clear();
    _repeat.clear();
    switch (widget.mode) {
      case AuthFormMode.signUp:
        if (confirmation) context.go('/access/confirm');
      case AuthFormMode.recovery:
        setState(() => _sent = true);
      case AuthFormMode.password:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).passwordUpdated)),
        );
        context.go('/profile');
      case AuthFormMode.signIn:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final action = ref.watch(authControllerProvider);
    final mode = widget.mode;
    final title = switch (mode) {
      AuthFormMode.signIn => s.signIn,
      AuthFormMode.signUp => s.signUp,
      AuthFormMode.recovery => s.recoverPassword,
      AuthFormMode.password => s.newPassword,
    };
    final password = mode != AuthFormMode.recovery;
    final repeat = mode == AuthFormMode.signUp || mode == AuthFormMode.password;
    final session = ref.watch(authSessionProvider);
    final recoveryWithoutSession =
        mode == AuthFormMode.password &&
        (session.isLoading || session.hasError || session.value == null);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      if (mode == AuthFormMode.recovery)
                        Text(s.recoveryDescription),
                      if (mode == AuthFormMode.signUp)
                        Text(s.registrationDescription),
                      if (recoveryWithoutSession) ...[
                        Text(s.recoveryLinkNeeded),
                        TextButton(
                          onPressed: () => context.go('/access/recovery'),
                          child: Text(s.recoverPassword),
                        ),
                      ] else if (_sent) ...[
                        Text(s.recoverySent),
                        TextButton(
                          onPressed: () => context.go('/access/login'),
                          child: Text(s.signIn),
                        ),
                      ] else ...[
                        if (mode != AuthFormMode.password)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: TextFormField(
                              key: const ValueKey('email'),
                              controller: _email,
                              enabled: !action.busy,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                              autofillHints: const [AutofillHints.email],
                              decoration: InputDecoration(labelText: s.email),
                              validator: (v) =>
                                  AuthValidation.validEmail(v ?? '')
                                  ? null
                                  : s.invalidEmail,
                            ),
                          ),
                        if (password)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextFormField(
                              key: const ValueKey('password'),
                              controller: _password,
                              obscureText: _hidden,
                              enabled: !action.busy,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: [
                                mode == AuthFormMode.signIn
                                    ? AutofillHints.password
                                    : AutofillHints.newPassword,
                              ],
                              decoration: InputDecoration(
                                labelText: mode == AuthFormMode.password
                                    ? s.newPassword
                                    : s.password,
                                helperText: mode == AuthFormMode.signIn
                                    ? null
                                    : s.passwordHint,
                                suffixIcon: IconButton(
                                  tooltip: _hidden
                                      ? s.showPassword
                                      : s.hidePassword,
                                  onPressed: action.busy
                                      ? null
                                      : () =>
                                            setState(() => _hidden = !_hidden),
                                  icon: Icon(
                                    _hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => mode == AuthFormMode.signIn
                                  ? ((v ?? '').isEmpty ? s.requiredField : null)
                                  : (AuthValidation.validPassword(v ?? '')
                                        ? null
                                        : s.invalidPassword),
                            ),
                          ),
                        if (repeat)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextFormField(
                              key: const ValueKey('repeat-password'),
                              controller: _repeat,
                              obscureText: _hidden,
                              enabled: !action.busy,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(
                                labelText: s.repeatPassword,
                              ),
                              validator: (v) => v == _password.text
                                  ? null
                                  : s.passwordMismatch,
                            ),
                          ),
                        if (action.failure != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                authFailureMessage(s, action.failure!),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const ValueKey('submit-auth'),
                          onPressed: action.busy ? null : _submit,
                          child: action.busy
                              ? Semantics(
                                  label: s.processing,
                                  child: const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : Text(
                                  mode == AuthFormMode.recovery
                                      ? s.sendRecovery
                                      : mode == AuthFormMode.password
                                      ? s.savePassword
                                      : title,
                                ),
                        ),
                        if (mode == AuthFormMode.signIn) ...[
                          TextButton(
                            onPressed: action.busy
                                ? null
                                : () => context.go('/access/recovery'),
                            child: Text(s.forgotPassword),
                          ),
                          TextButton(
                            onPressed: action.busy
                                ? null
                                : () => context.go('/access/register'),
                            child: Text(s.signUp),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
