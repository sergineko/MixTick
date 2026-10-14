// UI/state double only. Actual permissions and sockets live in shopping_local.
import 'dart:async';

import 'package:mixtick/features/cook_today/domain/matching.dart';
import 'package:mixtick/features/recipes/domain/recipe.dart';
import 'package:mixtick/features/shopping/domain/shopping.dart';
import 'package:mixtick/features/shopping/domain/shopping_repository.dart';

const shopList = ShoppingList(
  id: 'list-a',
  ownerId: 'test-a',
  title: 'Compra semanal',
  version: 1,
  shared: true,
);
const shopItem = ShoppingItem(
  id: 'item-a',
  name: 'Jabón',
  version: 1,
  purchased: false,
  quantity: 0.125,
  unit: 'l',
);
const importLine = MissingIngredient(
  lineId: 'line-a',
  ordinal: 0,
  ingredient: RecipeIngredient(
    customName: 'Miso blanco',
    name: 'Miso blanco',
    quantity: 2.5,
    unit: 'g',
  ),
);
const importPreview = ShoppingImportPreview(
  recipeId: 'recipe-a',
  version: 1,
  title: 'Receta original',
  servings: 2.5,
  lines: [importLine],
);

class FakeShoppingRepository implements ShoppingRepository {
  ShoppingSnapshot snapshot = const ShoppingSnapshot(
    shopList,
    [shopItem],
    [ShoppingMember('test-b', 'colabora')],
    [],
  );
  ShoppingImportPreview importData = importPreview;
  ShoppingFailureCode? readFailure, addFailure, editFailure;
  Completer<void>? holdRead, holdToggle;
  bool forbidden = false;
  int watches = 0, cancelled = 0, reads = 0, adds = 0, imports = 0, deleted = 0;
  final signals = <StreamController<ShoppingSignal>>[];
  final requests = <String>[];
  List<MissingIngredient> imported = [];
  @override
  Future<ShoppingOverview> overview() async =>
      ShoppingOverview(forbidden ? [] : [snapshot.list], []);
  @override
  Future<ShoppingSnapshot> read(String listId) async {
    reads++;
    final result = snapshot;
    await holdRead?.future;
    if (forbidden) throw const ShoppingFailure(ShoppingFailureCode.forbidden);
    if (readFailure != null) throw ShoppingFailure(readFailure!);
    return result;
  }

  @override
  Stream<ShoppingSignal> watch(String id) {
    watches++;
    late StreamController<ShoppingSignal> controller;
    controller = StreamController<ShoppingSignal>(
      onListen: () => controller.add(ShoppingSignal.connected),
      onCancel: () {
        cancelled++;
      },
    );
    signals.add(controller);
    return controller.stream;
  }

  void notify() {
    for (final stream in signals) {
      if (stream.hasListener) stream.add(ShoppingSignal.changed);
    }
  }

  @override
  Future<String> createList(String title, String request) async =>
      'created-list';
  @override
  Future<void> rename(ShoppingList list, String title) async {}
  @override
  Future<void> deleteList(ShoppingList list) async {
    deleted++;
  }

  @override
  Future<String> add(String id, ShoppingDraft draft, String request) async {
    adds++;
    requests.add(request);
    if (addFailure != null) throw ShoppingFailure(addFailure!);
    final item = ShoppingItem(
      id: 'added-$adds',
      name: draft.name,
      version: 1,
      purchased: false,
      quantity: draft.quantity,
      unit: draft.unit,
    );
    snapshot = ShoppingSnapshot(
      snapshot.list,
      [...snapshot.items, item],
      snapshot.members,
      snapshot.invitations,
    );
    return item.id;
  }

  @override
  Future<void> edit(ShoppingItem item, ShoppingDraft draft) async {
    if (editFailure != null) throw ShoppingFailure(editFailure!);
    snapshot = ShoppingSnapshot(
      snapshot.list,
      snapshot.items
          .map(
            (i) => i.id == item.id
                ? ShoppingItem(
                    id: i.id,
                    name: draft.name,
                    version: i.version + 1,
                    purchased: i.purchased,
                    quantity: draft.quantity,
                    unit: draft.unit,
                  )
                : i,
          )
          .toList(),
      snapshot.members,
      snapshot.invitations,
    );
  }

  @override
  Future<void> toggle(ShoppingItem item) async {
    await holdToggle?.future;
    snapshot = snapshot.toggle(item.id);
  }

  @override
  Future<void> remove(ShoppingItem item) async {
    snapshot = ShoppingSnapshot(
      snapshot.list,
      snapshot.items.where((i) => i.id != item.id).toList(),
      snapshot.members,
      snapshot.invitations,
    );
  }

  @override
  Future<void> invite(String id, String username) async {}
  @override
  Future<void> respond(ShoppingInvitation inv, bool accept) async {}
  @override
  Future<void> revoke(String id, String user) async {}
  @override
  Future<void> leave(String id) async {}
  @override
  Future<ShoppingImportPreview> preview(String id) async => importData;
  @override
  Future<List<String>> importIngredients(
    String id,
    ShoppingImportPreview preview,
    List<MissingIngredient> lines,
    String request, {
    bool missingOnly = false,
  }) async {
    imports++;
    imported = lines;
    return ['imported-item'];
  }
}
