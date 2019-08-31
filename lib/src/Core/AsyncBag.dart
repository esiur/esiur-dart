import 'AsyncReply.dart';

class AsyncBag<T> extends AsyncReply<List<T>> {
  List<AsyncReply<T>> _replies = List<AsyncReply<T>>();
  List<T> _results = List<T>();

  int _count = 0;
  bool _sealedBag = false;

  seal() {
    if (_sealedBag) {
      return;
    }
    _sealedBag = true;

    if (_results.length == 0) {
      trigger(List<T>());
    }

    for (var i = 0; i < _results.length; i++) {
      var k = _replies[i];
      var index = i;

      k.then((r) {
        _results[index] = r;
        _count++;
        if (_count == _results.length) {
          trigger(_results);
        }
      });
    }
  }

  add(AsyncReply<T> reply) {
    if (!_sealedBag) {
      _results.add(null);
      _replies.add(reply);
    }
  }

  addBag(AsyncBag<T> bag) {
    bag._replies.forEach((r) {
      add(r);
    });
  }
}
