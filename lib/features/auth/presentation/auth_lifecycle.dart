import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_providers.dart';
import '../../../core/network/supabase_bootstrap.dart';
import '../../../app/router.dart';

/// Native callbacks terminate at the repository; widgets never touch Supabase.
class AuthLifecycle extends ConsumerStatefulWidget {
  const AuthLifecycle({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AuthLifecycle> createState() => _AuthLifecycleState();
}

class _AuthLifecycleState extends ConsumerState<AuthLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _links;
  Timer? _validation;
  final _handled = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(backendProvider).client != null) {
      _startValidationTimer();
      final links = AppLinks();
      _links = links.uriLinkStream.listen(_callback, onError: (Object _) {});
      unawaited(
        links
            .getInitialLink()
            .then((uri) {
              if (uri != null && mounted) _callback(uri);
            })
            .catchError((Object _) {}),
      );
    }
  }

  void _startValidationTimer() {
    _validation?.cancel();
    _validation = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && ref.read(authSessionProvider).value != null) {
        unawaited(
          ref
              .read(authControllerProvider.notifier)
              .execute((repo) => repo.validateSession()),
        );
      }
    });
  }

  void _callback(Uri uri) {
    // Codes stay in memory only, to deduplicate initial-link/stream delivery.
    if (!_handled.add(uri.toString())) return;
    if (_handled.length > 16) _handled.remove(_handled.first);
    unawaited(
      ref.read(authControllerProvider.notifier).processCallback(uri).then((
        success,
      ) {
        if (!success && mounted) {
          ref.read(routerProvider).go('/access/link-error');
        }
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authRepositoryProvider) != null) {
      unawaited(
        ref
            .read(authControllerProvider.notifier)
            .execute((repo) => repo.validateSession()),
      );
      _startValidationTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _validation?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _validation?.cancel();
    unawaited(_links?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
