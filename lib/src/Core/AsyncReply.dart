/*
 
Copyright (c) 2019 Ahmed Kh. Zamil

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/
import 'dart:async';
import 'dart:core';
import 'AsyncException.dart';
import 'ProgressType.dart';

class AsyncReply<T> implements Future<T> {
  List<Function(T)> _callbacks = <Function(T)>[];

  T _result;

  List<Function(AsyncException)> _errorCallbacks = <Function(AsyncException)>[];

  List<Function(ProgressType, int, int)> _progressCallbacks =
      <Function(ProgressType, int, int)>[];

  List<Function(T)> _chunkCallbacks = <Function(T)>[];

  bool _resultReady = false;
  AsyncException _exception;

  bool get ready {
    return _resultReady;
  }

  set ready(value) {
    _resultReady = value;
  }

  T get result {
    return _result;
  }

  setResultReady(bool val) {
    _resultReady = val;
  }

  AsyncReply<T> next(Function(T) callback) {
    then(callback);
    return this;
  }

  AsyncReply<R> then<R>(FutureOr<R> onValue(T value), {Function onError}) {
    _callbacks.add(onValue);
    if (onError != null) {
      if (onError is Function(dynamic, dynamic)) {
        _errorCallbacks.add((ex) => onError(ex, null));
      } else if (onError is Function(dynamic)) {
        _errorCallbacks.add(onError);
      } else if (onError is Function()) {
        _errorCallbacks.add((ex) => onError());
      } else if (onError is Function(Object, StackTrace)) {
        _errorCallbacks.add((ex) => onError(ex, null));
      }
    }

    if (_resultReady) onValue(result);

    if (R == Null)
      return null;
    else
      return this as AsyncReply<R>;
  }

  AsyncReply<T> whenComplete(FutureOr action()) {
    return this;
    //_callbacks.add(action);
  }

  Stream<T> asStream() {
    return null;
  }

  AsyncReply<T> catchError(Function onError, {bool test(Object error)}) {
    return this.error(onError);
  }

  AsyncReply<T> timeout(Duration timeLimit, {FutureOr<T> onTimeout()}) {
    return this;
  }

  AsyncReply<T> error(Function(dynamic) callback) {
    _errorCallbacks.add(callback);

    if (_exception != null) callback(_exception);

    return this;
  }

  AsyncReply<T> progress(Function(ProgressType, int, int) callback) {
    _progressCallbacks.add(callback);
    return this;
  }

  AsyncReply<T> chunk(Function(T) callback) {
    _chunkCallbacks.add(callback);
    return this;
  }

  AsyncReply<T> trigger(T result) {
    if (_resultReady) return this;

    _result = result;
    _resultReady = true;

    _callbacks.forEach((x) {
      x(result);
    });

    return this;
  }

  AsyncReply<T> triggerError(Exception exception) {
    if (_resultReady) return this;

    if (exception is AsyncException)
      _exception = exception;
    else
      _exception = AsyncException.toAsyncException(exception);

    ///lock (callbacksLock)
    //{

    if (this._errorCallbacks.length == 0)
      throw _exception;
    else
      _errorCallbacks.forEach((x) {
        x(_exception);
      });
    //}

    return this;
  }

  AsyncReply<T> triggerProgress(ProgressType type, int value, int max) {
    _progressCallbacks.forEach((x) {
      x(type, value, max);
    });

    return this;
  }

  AsyncReply<T> triggerChunk(T value) {
    _chunkCallbacks.forEach((x) {
      x(value);
    });

    return this;
  }

  AsyncReply.ready(T result) {
    _resultReady = true;
    _result = result;
  }

  AsyncReply() {}
}
