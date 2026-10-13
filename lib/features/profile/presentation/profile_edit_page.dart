import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/widgets/app_states.dart';
import '../domain/user_profile.dart';
import 'profile_providers.dart';
import 'profile_widgets.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});
  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _name = TextEditingController();
  bool _loaded = false;
  bool _picking = false;
  bool _removePhoto = false;
  Uint8List? _photo;
  Object? _pickerError;
  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _photo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final action = ref.watch(profileControllerProvider);
    final busy = action.busy || _picking;
    return Scaffold(
      appBar: AppBar(title: Text(s.editProfile)),
      body: SafeArea(
        child: ref
            .watch(ownProfileProvider)
            .when(
              skipLoadingOnRefresh: false,
              loading: () => AppLoadingState(label: s.loadingProfile),
              error: (error, _) => AppErrorState(
                message: profileErrorMessage(s, error),
                actionLabel: s.retry,
                onAction: () => ref.invalidate(ownProfileProvider),
              ),
              data: (profile) {
                if (!_loaded) {
                  _username.text = profile?.username ?? '';
                  _name.text = profile?.displayName ?? '';
                  _loaded = true;
                }
                return Center(
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
                            Center(
                              child: _photo == null
                                  ? ProfileAvatar(
                                      path: _removePhoto
                                          ? null
                                          : profile?.avatarPath,
                                    )
                                  : ClipOval(
                                      child: Image.memory(
                                        _photo!,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        semanticLabel: s.profilePhoto,
                                      ),
                                    ),
                            ),
                            if (profile == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(s.photoAfterProfile),
                              )
                            else ...[
                              TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        setState(() {
                                          _picking = true;
                                          _pickerError = null;
                                        });
                                        try {
                                          final photo = await ref
                                              .read(photoPickerProvider)
                                              .pick();
                                          if (mounted && photo != null) {
                                            setState(() {
                                              _photo = photo;
                                              _removePhoto = false;
                                            });
                                          }
                                        } catch (error) {
                                          if (mounted) {
                                            setState(
                                              () => _pickerError = error,
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => _picking = false);
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(s.choosePhoto),
                              ),
                              if (_photo != null || profile.avatarPath != null)
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () {
                                          setState(() {
                                            _photo = null;
                                            _removePhoto = true;
                                          });
                                        },
                                  child: Text(s.removePhoto),
                                ),
                            ],
                            const SizedBox(height: 24),
                            TextFormField(
                              key: const ValueKey('display-name'),
                              controller: _name,
                              enabled: !busy,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 60,
                              decoration: InputDecoration(
                                labelText: s.displayName,
                              ),
                              validator: (v) =>
                                  ProfileValidation.validDisplayName(v ?? '')
                                  ? null
                                  : s.invalidDisplayName,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('username'),
                              controller: _username,
                              enabled: !busy,
                              autocorrect: false,
                              enableSuggestions: false,
                              maxLength: 30,
                              decoration: InputDecoration(
                                labelText: s.username,
                                helperText: s.usernameHint,
                              ),
                              validator: (v) =>
                                  ProfileValidation.validUsername(v ?? '')
                                  ? null
                                  : s.invalidUsername,
                            ),
                            if (_pickerError != null)
                              Text(profileErrorMessage(s, _pickerError!)),
                            if (action.failure != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  profileErrorMessage(
                                    s,
                                    ProfileFailure(action.failure!),
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            if (action.failure == ProfileFailureCode.conflict)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () {
                                        setState(() {
                                          _loaded = false;
                                          _photo = null;
                                          _removePhoto = false;
                                        });
                                        ref.invalidate(ownProfileProvider);
                                      },
                                child: Text(s.reloadProfile),
                              ),
                            const SizedBox(height: 24),
                            FilledButton(
                              key: const ValueKey('save-profile'),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (!_form.currentState!.validate()) {
                                        return;
                                      }
                                      final success = await ref
                                          .read(
                                            profileControllerProvider.notifier,
                                          )
                                          .save(
                                            username: _username.text,
                                            displayName: _name.text,
                                            previous: profile,
                                            photo: _photo,
                                            removePhoto: _removePhoto,
                                          );
                                      if (!mounted || !success) return;
                                      final pending = ref
                                          .read(profileControllerProvider)
                                          .cleanupPending;
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  pending
                                                      ? s.photoCleanupPending
                                                      : s.profileSaved,
                                                ),
                                              ),
                                            );
                                        context.go('/profile');
                                      }
                                    },
                              child: Text(busy ? s.processing : s.saveProfile),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
