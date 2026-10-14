import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_bootstrap.dart';
import '../../recipes/presentation/recipe_providers.dart';
import '../data/supabase_shopping_repository.dart';
import '../domain/shopping.dart';
import '../domain/shopping_repository.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository?>((ref) {
  final client = ref.watch(backendProvider).client;
  return client == null ? null : SupabaseShoppingRepository(client);
});
final shoppingOverviewProvider = FutureProvider.autoDispose<ShoppingOverview>((
  ref,
) async {
  final actor = ref.watch(recipeActorProvider),
      repo = ref.watch(shoppingRepositoryProvider);
  if (actor == null || repo == null) return const ShoppingOverview([], []);
  return repo.overview();
}, retry: (_, _) => null);
final shoppingPreviewProvider = FutureProvider.autoDispose
    .family<ShoppingImportPreview, String>((ref, id) async {
      if (ref.watch(recipeActorProvider) == null) {
        throw const ShoppingFailure(ShoppingFailureCode.forbidden);
      }
      final repo = ref.watch(shoppingRepositoryProvider);
      if (repo == null) {
        throw const ShoppingFailure(ShoppingFailureCode.network);
      }
      return repo.preview(id);
    }, retry: (_, _) => null);

class ShoppingView {
  const ShoppingView({
    this.snapshot,
    this.failure,
    this.busy = false,
    this.refreshing = false,
    this.signal = ShoppingSignal.connecting,
  });
  final ShoppingSnapshot? snapshot;
  final Object? failure;
  final bool busy, refreshing;
  final ShoppingSignal signal;
}

final shoppingDetailProvider = AsyncNotifierProvider.autoDispose
    .family<ShoppingController, ShoppingView, String>(
      ShoppingController.new,
      retry: (_, _) => null,
    );

class ShoppingController extends AsyncNotifier<ShoppingView> {
  ShoppingController(this.id);
  final String id;
  int generation = 0, readGeneration = 0;
  bool connected = false;
  void Function()? stopWatching;
  @override
  Future<ShoppingView> build() async {
    final epoch = ++generation;
    connected = false;
    final actor = ref.watch(recipeActorProvider),
        repo = ref.watch(shoppingRepositoryProvider);
    if (actor == null || repo == null) {
      throw const ShoppingFailure(ShoppingFailureCode.forbidden);
    }
    Timer? debounce;
    var listening = true;
    final sub = repo
        .watch(id)
        .listen(
          (signal) {
            if (!listening || !current(epoch, actor)) return;
            if (signal != ShoppingSignal.changed) {
              connected = signal == ShoppingSignal.connected;
              final old = state.value;
              if (old != null) {
                state = AsyncData(
                  ShoppingView(
                    snapshot: old.snapshot,
                    failure: old.failure,
                    busy: old.busy,
                    refreshing: old.refreshing,
                    signal: signal,
                  ),
                );
              }
            }
            if (signal == ShoppingSignal.changed ||
                signal == ShoppingSignal.connected) {
              debounce?.cancel();
              debounce = Timer(
                const Duration(milliseconds: 200),
                () => refresh(),
              );
            }
          },
          onError: (Object error) {
            if (listening && current(epoch, actor)) {
              state = AsyncData(
                ShoppingView(
                  failure: error,
                  signal: ShoppingSignal.disconnected,
                ),
              );
              if (error is ShoppingFailure &&
                  error.code == ShoppingFailureCode.forbidden) {
                stopWatching?.call();
              }
            }
          },
        );
    final probe = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    void stop() {
      listening = false;
      connected = false;
      debounce?.cancel();
      probe.cancel();
      unawaited(sub.cancel());
    }

    stopWatching = stop;
    ref.onCancel(stop);
    ref.onResume(ref.invalidateSelf);
    ref.onDispose(() {
      generation++;
      stop();
    });
    final snapshot = await repo.read(id);
    return ShoppingView(
      snapshot: snapshot,
      signal: connected ? ShoppingSignal.connected : ShoppingSignal.connecting,
    );
  }

  bool current(int epoch, String actor) =>
      ref.mounted &&
      generation == epoch &&
      ref.read(recipeActorProvider) == actor;
  Future<void> refresh({bool afterWrite = false}) async {
    final previous = state.value;
    if (previous == null || previous.snapshot == null && !afterWrite) {
      ref.invalidateSelf();
      return;
    }
    if (previous.busy && !afterWrite) return;
    final repo = ref.read(shoppingRepositoryProvider),
        actor = ref.read(recipeActorProvider);
    if (repo == null || actor == null) return;
    final epoch = generation, read = ++readGeneration;
    state = AsyncData(
      ShoppingView(
        snapshot: previous.snapshot,
        busy: previous.busy,
        refreshing: true,
        signal: previous.signal,
      ),
    );
    try {
      final snapshot = await repo.read(id);
      if (!current(epoch, actor) || read != readGeneration) return;
      state = AsyncData(
        ShoppingView(
          snapshot: snapshot,
          busy: previous.busy,
          signal: connected
              ? ShoppingSignal.connected
              : ShoppingSignal.disconnected,
        ),
      );
    } catch (error) {
      if (current(epoch, actor) && read == readGeneration) {
        if (error is ShoppingFailure &&
            error.code == ShoppingFailureCode.forbidden) {
          stopWatching?.call();
        }
        state = AsyncData(
          ShoppingView(
            failure: error,
            busy: previous.busy,
            signal: ShoppingSignal.disconnected,
          ),
        );
      }
    }
  }

  Future<bool> perform(
    Future<void> Function(ShoppingRepository) operation, {
    String? toggleId,
  }) async {
    final previous = state.value;
    final repo = ref.read(shoppingRepositoryProvider),
        actor = ref.read(recipeActorProvider);
    if (previous == null ||
        previous.busy ||
        previous.snapshot == null ||
        repo == null ||
        actor == null) {
      return false;
    }
    final epoch = generation;
    ++readGeneration; // A read started before this optimistic write cannot undo it.
    state = AsyncData(
      ShoppingView(
        snapshot: toggleId == null
            ? previous.snapshot
            : previous.snapshot!.toggle(toggleId),
        busy: true,
        signal: previous.signal,
      ),
    );
    Object? failure;
    try {
      await operation(repo);
    } catch (error) {
      failure = error;
    }
    if (!current(epoch, actor)) return false;
    await refresh(afterWrite: true);
    if (!current(epoch, actor)) return false;
    final actual = state.value!;
    state = AsyncData(
      ShoppingView(
        snapshot: actual.snapshot,
        failure: failure ?? actual.failure,
        signal: actual.signal,
      ),
    );
    ref.invalidate(shoppingOverviewProvider);
    return failure == null && actual.snapshot != null;
  }
}
