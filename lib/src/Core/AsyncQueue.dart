library esiur;

import 'AsyncReply.dart';

class AsyncQueue<T> extends AsyncReply<T> {
  List<AsyncReply<T>> _list = <AsyncReply<T>>[];

  void add(AsyncReply<T> reply) {
    _list.add(reply);

    super.setResultReady(false);

    reply.then(processQueue);
  }

  void remove(AsyncReply<T> reply) {
    _list.remove(reply);
    processQueue();
  }

  void processQueue([T o = null]) {
    for (var i = 0; i < _list.length; i++) {
      if (_list[i].ready) {
        super.trigger(_list[i].result);
        _list.removeAt(i);
        i--;
      } else {
        break;
      }
    }

    super.setResultReady(_list.length == 0);
  }
}
