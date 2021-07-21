import 'AsyncReply.dart';
import '../Resource/Warehouse.dart';


class AsyncBag<T> extends AsyncReply<List<T>> {
  List<AsyncReply<T>> _replies = <AsyncReply<T>>[];
  List<T> _results = <T>[];

  int _count = 0;
  bool _sealedBag = false;

  Type arrayType;

  seal() {
    //print("SEALED");

    if (_sealedBag) return;

    _sealedBag = true;

    if (_results.length == 0) trigger(<T>[]);

    for (var i = 0; i < _results.length; i++) {
      var k = _replies[i];
      var index = i;

      k.then<dynamic>((r) {
        _results[index] = r;
        _count++;
        if (_count == _results.length) {
          if (arrayType != null) {
            var ar = Warehouse.createArray(arrayType);
            _results.forEach(ar.add);
            trigger(ar);
          } else {
            trigger(_results);
          }
        }
      }).error((ex) {
        triggerError(ex);
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

  AsyncBag() {}
}
