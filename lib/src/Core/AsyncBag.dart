import 'AsyncReply.dart';
import '../Resource/Warehouse.dart';

// class ReplyIndex<T> {
//   int index;
//   AsyncReply<T> reply;
//   T
// }

class AsyncBag<T> extends AsyncReply<List<T>> {
  List<AsyncReply<T>> _replies = <AsyncReply<T>>[];

  //List<T?> _results = <T>[];

  int _count = 0;
  bool _sealedBag = false;

  Type? arrayType;

  seal() {
    //print("SEALED");

    if (_sealedBag) return;
    _sealedBag = true;

    if (_replies.length == 0) {
      if (arrayType != null) {
        var ar = Warehouse.createArray(arrayType as Type);
        trigger(ar as List<T>);
      } else {
        trigger(<T>[]);
      }
    }

    var results = List<T?>.filled(_replies.length, null);

    for (var i = 0; i < _replies.length; i++) {
      var k = _replies[i];
      var index = i;

      k
        ..then((r) {
          results[index] = r;
          _count++;
          if (_count == _replies.length) {
            if (arrayType != null) {
              var ar = Warehouse.createArray(arrayType as Type);
              results.forEach(ar.add);
              trigger(ar as List<T>);
            } else {
              trigger(results.cast<T>());
            }
          }
        })
        ..error((ex) {
          triggerError(ex);
        });
    }
  }

  void add(AsyncReply<T> reply) {
    if (!_sealedBag) {
      //_results.add(null);
      _replies.add(reply);
    }
  }

  void addBag(AsyncBag<T> bag) {
    bag._replies.forEach((r) {
      add(r);
    });
  }

  AsyncBag() {}
}
