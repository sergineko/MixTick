import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../domain/user_profile.dart';

class ProfileLookupPage extends StatefulWidget {
  const ProfileLookupPage({super.key});
  @override
  State<ProfileLookupPage> createState() => _ProfileLookupPageState();
}

class _ProfileLookupPageState extends State<ProfileLookupPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.findProfile)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.findProfileDescription),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _username,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: s.username,
                        helperText: s.usernameHint,
                        helperMaxLines: 4,
                        errorMaxLines: 3,
                      ),
                      validator: (value) =>
                          ProfileValidation.validUsername(value ?? '')
                          ? null
                          : s.invalidUsername,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        if (_form.currentState!.validate()) {
                          context.push(
                            '/people/${ProfileValidation.normalizeUsername(_username.text)}',
                          );
                        }
                      },
                      child: Text(s.viewProfile),
                    ),
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
