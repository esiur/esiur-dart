library esiur;

import 'AsyncReply.dart';

class AsyncQueue<T> extends AsyncReply<T>
{
    List<AsyncReply<T>> _list = new List<AsyncReply<T>>();

//      object queueLock = new object();
  
      add(AsyncReply<T> reply)
      {
          //lock (queueLock)
              _list.add(reply);

          //super._resultReady = false;
          super.setResultReady(false);

          reply.then(processQueue);
      }

      remove(AsyncReply<T> reply)
      {
          //lock (queueLock)
              _list.remove(reply);
          processQueue(null);
      }

      void processQueue(T o)
      {
          //lock (queueLock)
              for (var i = 0; i < _list.length; i++)
                  if (_list[i].ready)
                  {
                      super.trigger(_list[i].result);
                      _list.removeAt(i);
                      i--;
                  }
                  else
                      break;

      
          //super._resultReady = (_list.length == 0);
          super.setResultReady(_list.length == 0);
      }

      AsyncQueue()
      {

      }
  }
