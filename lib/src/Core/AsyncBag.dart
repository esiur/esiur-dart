import 'AsyncReply.dart';

class AsyncBag<T> extends AsyncReply<List<T>>
{

    List<AsyncReply<T>> _replies = new List<AsyncReply<T>>();
    List<T> _results = new List<T>();

    int _count = 0;
    bool _sealedBag = false;

    seal()
    {
        //print("SEALED");
      
        if (_sealedBag)
            return;

        _sealedBag = true;

        if (_results.length == 0)
            trigger(new List<T>());

        for (var i = 0; i < _results.length; i++)
        {
            var k = _replies[i];
            var index = i;

            k.then((r)
            {
                _results[index] = r;
                _count++;
                //print("Seal ${_count}/${_results.length}");
                if (_count == _results.length)
                    trigger(_results);
            }).error((ex){
              triggerError(ex);
            });
        }
    }

    add(AsyncReply<T> reply)
    {
        if (!_sealedBag)
        {
            _results.add(null);
            _replies.add(reply);
        }
    }

    addBag(AsyncBag<T> bag)
    {
        bag._replies.forEach((r) {
          add(r);
        });
    }

    AsyncBag()
    {

    }

}
