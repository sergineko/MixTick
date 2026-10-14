import '../../cook_today/domain/matching.dart';

enum ShoppingFailureCode {
  network,
  forbidden,
  conflict,
  invalid,
  quota,
  unexpected,
}

class ShoppingFailure implements Exception {
  const ShoppingFailure(this.code);
  final ShoppingFailureCode code;
}

enum ShoppingSignal { connecting, connected, disconnected, changed }

class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.version,
    this.shared = false,
  });
  final String id, ownerId, title;
  final int version;
  final bool shared;
  factory ShoppingList.fromJson(Map<String, dynamic> j) => ShoppingList(
    id: j['id'] as String,
    ownerId: j['owner_id'] as String,
    title: j['title'] as String,
    version: (j['version'] as num).toInt(),
    shared: (j['shopping_list_members'] as List?)?.isNotEmpty ?? false,
  );
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.version,
    required this.purchased,
    this.ingredientId,
    this.quantity,
    this.unit,
  });
  final String id, name;
  final String? ingredientId, unit;
  final double? quantity;
  final int version;
  final bool purchased;
  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
    id: j['id'] as String,
    name: j['name'] as String,
    version: (j['version'] as num).toInt(),
    purchased: j['is_purchased'] as bool,
    ingredientId: j['ingredient_id'] as String?,
    quantity: (j['quantity'] as num?)?.toDouble(),
    unit: j['unit'] as String?,
  );
  ShoppingItem toggled() => ShoppingItem(
    id: id,
    name: name,
    version: version,
    purchased: !purchased,
    ingredientId: ingredientId,
    quantity: quantity,
    unit: unit,
  );
}

class ShoppingDraft {
  const ShoppingDraft(this.name, {this.quantity, this.unit, this.ingredientId});
  final String name;
  final double? quantity;
  final String? unit, ingredientId;
  bool get valid =>
      name.trim().runes.isNotEmpty &&
      name.trim().runes.length <= 80 &&
      (unit == null ||
          unit!.trim().runes.isNotEmpty && unit!.trim().runes.length <= 30) &&
      (quantity == null ||
          quantity!.isFinite &&
              quantity! > 0 &&
              quantity! <= 1000000 &&
              (quantity! * 1000 - (quantity! * 1000).round()).abs() < 0.00001);
  Map<String, dynamic> get json => {
    'name': name.trim(),
    'quantity': quantity,
    'unit': unit?.trim(),
    'ingredient_id': ingredientId,
  };
  Map<String, dynamic> get changes => {
    'name': name.trim(),
    'quantity': quantity,
    'unit': unit?.trim(),
  };
}

class ShoppingMember {
  const ShoppingMember(this.id, this.username);
  final String id;
  final String? username;
}

class ShoppingInvitation {
  const ShoppingInvitation({
    required this.id,
    required this.listId,
    required this.inviteeId,
    this.title,
    this.username,
  });
  final String id, listId, inviteeId;
  final String? title, username;
  factory ShoppingInvitation.fromJson(Map<String, dynamic> j) =>
      ShoppingInvitation(
        id: j['id'] as String,
        listId: j['list_id'] as String,
        inviteeId: j['invitee_id'] as String,
        title: j['title'] as String?,
        username: (j['sender'] ?? j['username']) as String?,
      );
}

class ShoppingOverview {
  const ShoppingOverview(this.lists, this.invitations);
  final List<ShoppingList> lists;
  final List<ShoppingInvitation> invitations;
}

class ShoppingSnapshot {
  const ShoppingSnapshot(this.list, this.items, this.members, this.invitations);
  final ShoppingList list;
  final List<ShoppingItem> items;
  final List<ShoppingMember> members;
  final List<ShoppingInvitation> invitations;
  factory ShoppingSnapshot.fromJson(Map<String, dynamic> j) => ShoppingSnapshot(
    ShoppingList.fromJson(j['list'] as Map<String, dynamic>),
    List.unmodifiable(
      (j['items'] as List).map(
        (v) => ShoppingItem.fromJson(v as Map<String, dynamic>),
      ),
    ),
    List.unmodifiable(
      (j['members'] as List).map(
        (v) => ShoppingMember(v['user_id'] as String, v['username'] as String?),
      ),
    ),
    List.unmodifiable(
      (j['invitations'] as List).map(
        (v) => ShoppingInvitation.fromJson(v as Map<String, dynamic>),
      ),
    ),
  );
  ShoppingSnapshot toggle(String id) => ShoppingSnapshot(
    list,
    List.unmodifiable(items.map((i) => i.id == id ? i.toggled() : i)),
    members,
    invitations,
  );
}

class ShoppingImportPreview {
  const ShoppingImportPreview({
    required this.recipeId,
    required this.version,
    required this.title,
    required this.servings,
    required this.lines,
  });
  final String recipeId, title;
  final int version;
  final double servings;
  final List<MissingIngredient> lines;
  factory ShoppingImportPreview.fromJson(Map<String, dynamic> j) =>
      ShoppingImportPreview(
        recipeId: j['recipe_id'] as String,
        version: (j['version'] as num).toInt(),
        title: j['title'] as String,
        servings: (j['servings'] as num).toDouble(),
        lines: List.unmodifiable(
          (j['lines'] as List).map(
            (v) => MissingIngredient.fromJson(v as Map<String, dynamic>),
          ),
        ),
      );
  bool accepts(MissingIngredientsTransfer transfer) =>
      recipeId == transfer.recipeId &&
      version == transfer.recipeVersion &&
      transfer.lines.isNotEmpty &&
      transfer.lines.every(
        (old) => lines.any(
          (fresh) =>
              fresh.lineId == old.lineId &&
              fresh.ordinal == old.ordinal &&
              !fresh.ingredient.optional,
        ),
      );
}
