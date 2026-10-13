import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/supabase_bootstrap.dart';

final contentRouteObserverProvider =
    Provider<RouteObserver<ModalRoute<dynamic>>>(
      (ref) => RouteObserver<ModalRoute<dynamic>>(),
    );

/// No offline cache promise: recheck on return/resume and while visible.
class AccessRevalidation extends ConsumerStatefulWidget {
  const AccessRevalidation({
    required this.onRevalidate,
    required this.child,
    super.key,
  });
  final VoidCallback onRevalidate;
  final Widget child;
  @override
  ConsumerState<AccessRevalidation> createState() => _AccessRevalidationState();
}

class _AccessRevalidationState extends ConsumerState<AccessRevalidation>
    with WidgetsBindingObserver, RouteAware {
  Timer? timer;
  RouteObserver<ModalRoute<dynamic>>? observer;
  ModalRoute<dynamic>? route;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(backendProvider).client != null) {
      timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted &&
            route?.isCurrent == true &&
            TickerMode.valuesOf(context).enabled) {
          widget.onRevalidate();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (next != route) {
      observer?.unsubscribe(this);
      route = next;
      observer = ref.read(contentRouteObserverProvider);
      if (next != null) observer!.subscribe(this, next);
    }
  }

  @override
  void didPopNext() => widget.onRevalidate();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onRevalidate();
  }

  @override
  void dispose() {
    timer?.cancel();
    observer?.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
