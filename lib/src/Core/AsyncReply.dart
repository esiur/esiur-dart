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
  AsyncReply();

  List<Function(T)> _callbacks = <Function(T)>[];

  T _result;

  final _errorCallbacks = <Function(AsyncException)>[];

  final _progressCallbacks = <Function(ProgressType, int, int)>[];

  final _chunkCallbacks = <Function(T)>[];

  bool _resultReady = false;
  AsyncException _exception;

  bool get ready => _resultReady;

  T get result => _result;

  setResultReady(bool val) => _resultReady = val;

  AsyncReply<R> then<R>(FutureOr<R> onValue(T value), {Function onError}) {
    _callbacks.add(onValue);

    if (onError != null) {
      if (onError is Function(dynamic, dynamic)) {
        _errorCallbacks.add((ex) => onError(ex, null));
      } else if (onError is Function(dynamic)) {
        _errorCallbacks.add(onError);
      } else if (onError is Function()) {
        _errorCallbacks.add((ex) => onError());
      }
    }

    if (_resultReady) onValue(result);

    return this as AsyncReply<R>;
  }

  AsyncReply<T> whenComplete(FutureOr action()) => this;

  Stream<T> asStream() => null;

  AsyncReply<T> catchError(Function onError, {bool test(Object error)}) =>
      this.error(onError);

  AsyncReply<T> timeout(Duration timeLimit, {FutureOr<T> onTimeout()}) => this;

  @deprecated
  AsyncReply<T> _then_old(Function(T) callback) {
    _callbacks.add(callback);

    if (_resultReady) callback(result);

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

  void trigger(T result) {
    if (_resultReady) {
      return;
    }

    _result = result;
    _resultReady = true;

    _callbacks.forEach((x) {
      x(result);
    });
  }

  triggerError(Exception exception) {
    if (_resultReady) {
      return;
    }

    _exception = AsyncException.toAsyncException(exception);

    _errorCallbacks.forEach((x) {
      x(_exception);
    });
  }

  triggerProgress(ProgressType type, int value, int max) {
    if (_resultReady) {
      return;
    }

    _progressCallbacks.forEach((x) {
      x(type, value, max);
    });
  }

  triggerChunk(T value) {
    if (_resultReady) return;

    _chunkCallbacks.forEach((x) {
      x(value);
    });
  }

  AsyncReply.ready(T result) {
    _resultReady = true;
    _result = result;
  }
}
