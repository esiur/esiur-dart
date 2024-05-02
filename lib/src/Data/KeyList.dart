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
import '../Core/IEventHandler.dart';
import '../Core/IDestructible.dart';

import 'dart:collection';
import 'Codec.dart';

class KeyList<KT, T> extends IEventHandler with MapMixin<KT, T> {
  dynamic owner;

  Map<KT, T> _map = new Map<KT, T>();

  Iterator<KT> get iterator => _map.keys.iterator;

  Iterable<KT> get keys => _map.keys;
  Iterable<T> get values => _map.values;

  //T? operator [](Object? key);
  //operator []=(KT key, T value);

  T? operator [](Object? index) => _map[index];

  operator []=(KT index, T value) => add(index, value);

  at(int index) => _map.values.elementAt(index);

  late bool _removableList;

  T? take(KT key) {
    if (_map.containsKey(key)) {
      var v = _map[key];
      remove(key);
      return v;
    } else
      return null;
  }

  List<T> toArray() => _map.values.toList();

  void add(KT key, T value) {
    if (_removableList) if (value != null)
      (value as IDestructible).on("destroy", _itemDestroyed);

    if (_map.containsKey(key)) {
      var oldValue = _map[key];
      if (_removableList) if (oldValue != null)
        (oldValue as IDestructible).off("destroy", _itemDestroyed);

      _map[key] = value;

      emitArgs("modified", [key, oldValue, value, this]);
    } else {
      _map[key] = value;

      emitArgs("add", [value, this]);
    }
  }

  T? first(bool Function(T element) selector) {
    final res = _map.values.where(selector);
    return res.isEmpty ? null : res.first;
  }

  _itemDestroyed(T sender) {
    removeValue(sender);
  }

  removeValue(T value) {
    var toRemove = <KT>[];
    for (var k in _map.keys) if (_map[k] == value) toRemove.add(k);

    for (var k in toRemove) remove(k);
  }

  clear() {
    if (_removableList)
      for (var v in _map.values)
        (v as IDestructible).off("destroy", _itemDestroyed);

    _map.clear();

    emitArgs("cleared", [this]);
  }

  T? remove(key) {
    if (!_map.containsKey(key)) return null;

    var value = _map[key];

    if (_removableList) (value as IDestructible).off("destroy", _itemDestroyed);

    _map.remove(key);

    emitArgs("removed", [key, value, this]);

    return value;
  }

  int get count => _map.length;

  bool contains(KT key) => _map.containsKey(key);

  KeyList([owner = null]) {
    _removableList = Codec.implementsInterface<T, IDestructible>();
    this.owner = owner;
  }
}
