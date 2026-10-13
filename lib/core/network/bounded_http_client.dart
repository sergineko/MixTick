import 'dart:async';

import 'package:http/http.dart' as http;

/// Cancels the actual request, including its response body, on timeout.
/// Auth mutations remain locked until the SDK operation finishes; no late
/// successful response can silently replace a later account's session.
class BoundedHttpClient extends http.BaseClient {
  BoundedHttpClient({
    http.Client? inner,
    this.timeout = const Duration(seconds: 15),
  }) : _inner = inner ?? http.Client();
  final http.Client _inner;
  final Duration timeout;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abort = Completer<void>();
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    final timer = Timer(timeout, cancel);
    if (request is http.Abortable && request.abortTrigger != null) {
      unawaited(request.abortTrigger!.then((_) => cancel()));
    }
    // MultipartRequest adds its MIME boundary during finalize(). Copy headers
    // afterwards so Storage receives the exact body/Content-Type pair.
    final originalBody = request.finalize();
    final guarded =
        http.AbortableStreamedRequest(
            request.method,
            request.url,
            abortTrigger: abort.future,
          )
          ..headers.addAll(request.headers)
          ..followRedirects = request.followRedirects
          ..maxRedirects = request.maxRedirects
          ..persistentConnection = request.persistentConnection
          ..contentLength = request.contentLength;
    try {
      // Start sending and pumping together: StreamedRequest applies backpressure
      // before send() subscribes to its body, so awaiting addStream here deadlocks.
      unawaited(
        guarded.sink
            .addStream(originalBody)
            .then((_) => guarded.sink.close())
            .catchError((Object error, StackTrace stack) {
              guarded.sink.addError(error, stack);
              return guarded.sink.close();
            }),
      );
      final response = await _inner.send(guarded);
      Stream<List<int>> body() async* {
        try {
          yield* response.stream;
        } finally {
          timer.cancel();
        }
      }

      return http.StreamedResponse(
        body(),
        response.statusCode,
        contentLength: response.contentLength,
        request: request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      timer.cancel();
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}
