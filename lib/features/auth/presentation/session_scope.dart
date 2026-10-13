import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// Discard form state on account changes without recreating the router.
class SessionScope extends ConsumerWidget {
  const SessionScope({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => KeyedSubtree(
    key: ValueKey(
      ref.watch(authSessionProvider.select((s) => s.value?.userId)),
    ),
    child: child,
  );
}
