import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_deletion_repository.dart';

class SupabaseAccountDeletionRepository implements AccountDeletionRepository {
  const SupabaseAccountDeletionRepository(this.client);
  final SupabaseClient client;
  @override
  Future<void> request(String password, String requestId) async {
    final actor = client.auth.currentUser?.id;
    if (actor == null) {
      throw const AccountDeletionFailure(AccountDeletionFailureCode.forbidden);
    }
    void sameActor() {
      if (client.auth.currentUser?.id != actor) {
        throw const AccountDeletionFailure(
          AccountDeletionFailureCode.forbidden,
        );
      }
    }

    try {
      final prior = await client.rpc(
        'own_account_deletion',
        params: {'p_request_id': requestId},
      );
      sameActor();
      if (prior is Map && prior['accepted'] == true) return;
      final result = await client.functions.invoke(
        'delete-account',
        body: {
          'password': password,
          'confirmation': 'ELIMINAR',
          'delete_owned_lists': true,
          'request_id': requestId,
        },
      );
      sameActor();
      if (result.status != 202 ||
          result.data is! Map ||
          result.data['request_id'] != requestId ||
          result.data['accepted'] != true) {
        throw const AccountDeletionFailure(
          AccountDeletionFailureCode.unexpected,
        );
      }
    } on AccountDeletionFailure {
      rethrow;
    } on FunctionException catch (error) {
      throw AccountDeletionFailure(switch (error.status) {
        403 => AccountDeletionFailureCode.credentials,
        401 => AccountDeletionFailureCode.forbidden,
        400 || 413 => AccountDeletionFailureCode.invalid,
        503 => AccountDeletionFailureCode.network,
        _ => AccountDeletionFailureCode.unexpected,
      });
    } on SocketException {
      throw const AccountDeletionFailure(AccountDeletionFailureCode.network);
    } on TimeoutException {
      throw const AccountDeletionFailure(AccountDeletionFailureCode.network);
    } on http.ClientException {
      throw const AccountDeletionFailure(AccountDeletionFailureCode.network);
    } catch (_) {
      throw const AccountDeletionFailure(AccountDeletionFailureCode.unexpected);
    }
  }
}
