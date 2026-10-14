import '../../cook_today/domain/matching.dart';
import 'shopping.dart';

abstract interface class ShoppingRepository {
  Future<ShoppingOverview> overview();
  Future<ShoppingSnapshot> read(String listId);
  Future<String> createList(String title, String requestId);
  Future<void> rename(ShoppingList list, String title);
  Future<void> deleteList(ShoppingList list);
  Future<String> add(String listId, ShoppingDraft draft, String requestId);
  Future<void> edit(ShoppingItem item, ShoppingDraft draft);
  Future<void> toggle(ShoppingItem item);
  Future<void> remove(ShoppingItem item);
  Future<void> invite(String listId, String username);
  Future<void> respond(ShoppingInvitation invitation, bool accept);
  Future<void> revoke(String listId, String userId);
  Future<void> leave(String listId);
  Future<ShoppingImportPreview> preview(String recipeId);
  Future<List<String>> importIngredients(
    String listId,
    ShoppingImportPreview preview,
    List<MissingIngredient> lines,
    String requestId, {
    bool missingOnly = false,
  });
  Stream<ShoppingSignal> watch(String listId);
}
