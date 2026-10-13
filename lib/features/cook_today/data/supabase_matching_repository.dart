import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/matching.dart';

class SupabaseMatchingRepository implements MatchingRepository {
  const SupabaseMatchingRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 8;
  @override
  Future<MatchingPage> search(
    MatchingQuery query, {
    MatchingCursor? cursor,
    MatchingCancellation? cancellation,
  }) async {
    try {
      final actor = client.auth.currentUser?.id;
      if (actor == null) {
        throw const MatchingFailure(MatchingFailureCode.forbidden);
      }
      if (!query.valid) {
        throw const MatchingFailure(MatchingFailureCode.invalid);
      }
      if (query.selected.isEmpty) return const MatchingPage([]);
      final request = client.rpc(
        'cook_today_page',
        params: {
          'p_ids': query.ids,
          'p_names': query.names,
          'p_mode': query.mode.name,
          'p_after': cursor?.toJson(),
          'p_limit': pageSize + 1,
        },
      );
      final rows =
          await (cancellation == null
                  ? request
                  : request.abortSignal(cancellation.signal))
              as List;
      if (client.auth.currentUser?.id != actor) {
        throw const MatchingFailure(MatchingFailureCode.forbidden);
      }
      final matches = rows
          .take(pageSize)
          .map((r) => RecipeMatch.fromJson(r as Map<String, dynamic>))
          .toList();
      return MatchingPage(
        List.unmodifiable(matches),
        cursor: rows.length > pageSize ? matches.last.cursor : null,
      );
    } on MatchingFailure {
      rethrow;
    } on SocketException {
      throw const MatchingFailure(MatchingFailureCode.network);
    } on http.ClientException {
      throw const MatchingFailure(MatchingFailureCode.network);
    } on TimeoutException {
      throw const MatchingFailure(MatchingFailureCode.network);
    } on PostgrestException catch (e) {
      throw MatchingFailure(switch (e.code) {
        '42501' || 'PGRST301' || 'PGRST303' => MatchingFailureCode.forbidden,
        '22023' || '22P02' || '22003' => MatchingFailureCode.invalid,
        _ => MatchingFailureCode.unexpected,
      });
    } catch (_) {
      throw const MatchingFailure(MatchingFailureCode.unexpected);
    }
  }
}
