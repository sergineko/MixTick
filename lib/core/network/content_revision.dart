import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signals writes affecting visibility across the four existing modules.
final contentRevisionProvider = NotifierProvider<ContentRevision, int>(
  ContentRevision.new,
);

class ContentRevision extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}
