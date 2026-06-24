import 'dart:async';

/// Serializes read-modify-write work by key.
///
/// The Today page can edit different sections of the same Daily Markdown from
/// separate widgets. Chaining by vault path makes each mutation read the latest
/// local file and prevents stale writes from overwriting a previous operation.
class MutationQueue {
  final Map<String, Future<void>> _chains = {};

  Future<T> run<T>(String key, Future<T> Function() task) {
    final previous = _chains[key] ?? Future<void>.value();
    final completer = Completer<T>();

    final next = previous.catchError((_) {}).then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    _chains[key] = next.whenComplete(() {
      if (_chains[key] == next) {
        _chains.remove(key);
      }
    });

    return completer.future;
  }
}
