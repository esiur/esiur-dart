import '../Core/IDestructible.dart';
import 'Codec.dart';
import 'dart:collection';

class AutoList<T, ST> extends IDestructible with IterableMixin {
  List<T> _list = <T>[];

  ST _state;
  bool _removableList;

  sort(Function comparer) {
    _list.sort(comparer);
  }

  Iterator<T> get iterator => _list.iterator;

  /// <summary>
  /// Convert AutoList to array
  /// </summary>
  /// <returns>Array</returns>
  //List<T> toList()
  //{
  //    list.OrderBy()
  //    return _list;
  //}

  /// Create a new instance of AutoList
  /// <param name="state">State object to be included when an event is raised.</param>
  AutoList([ST state, List<T> values]) {
    this._state = state;
    this._removableList = Codec.implementsInterface<T, IDestructible>();

    if (values != null) addRange(values);

    register("modified");
    register("added");
    register("removed");
    register("cleared");
  }

  /// <summary>
  /// Synchronization lock of the list
  /// </summary>
  //public object SyncRoot
  //{
  //    get
  //    {
  //        return syncRoot;
  //    }
  //}

  /// <summary>
  /// First item in the list
  /// </summary>
  //T first()
  //{
  //    return _list.first;
  //}

  operator [](index) {
    return _list[index];
  }

  operator []=(index, value) {
    var oldValue = _list[index];

    if (_removableList) {
      if (oldValue != null)
        (oldValue as IDestructible).off("destroy", _itemDestroyed);
      if (value != null) value.on("destroy", _itemDestroyed);
    }

    //lock (syncRoot)
    _list[index] = value;

    emitArgs("modified", [_state, index, oldValue, value]);
  }

  /// <summary>
  /// Add item to the list
  /// </summary>
  add(T value) {
    if (_removableList) if (value != null)
      (value as IDestructible).on("destroy", _itemDestroyed);

    // lock (syncRoot)
    _list.add(value);

    emitArgs("add", [_state, value]);
  }

  /// <summary>
  /// Add an array of items to the list
  /// </summary>
  addRange(List<T> values) {
    values.forEach((x) => add(x));
  }

  _itemDestroyed(T sender) {
    remove(sender);
  }

  /// <summary>
  /// Clear the list
  /// </summary>
  clear() {
    if (_removableList)
      _list
          .forEach((x) => (x as IDestructible)?.off("destroy", _itemDestroyed));

//          lock (syncRoot)
    _list.clear();

    emitArgs("cleared", [_state]);
  }

  /// <summary>
  /// Remove an item from the list
  /// <param name="value">Item to remove</param>
  /// </summary>
  remove(T value) {
    if (!_list.contains(value)) return;

    if (_removableList) if (value != null)
      (value as IDestructible).off("destroy", _itemDestroyed);

    //lock (syncRoot)
    _list.remove(value);

    emitArgs("removed", [_state, value]);
  }

  /// <summary>
  /// Number of items in the list
  /// </summary>
  get count => _list.length;
  get length => _list.length;

  /// <summary>
  /// Check if an item exists in the list
  /// </summary>
  /// <param name="value">Item to check if exists</param>
  //contains(T value) => _list.contains(value);

  /// <summary>
  /// Check if any item of the given array is in the list
  /// </summary>
  /// <param name="values">Array of items</param>
  containsAny(values) {
    if (values is List<T>) {
      for (var v in values) {
        if (_list.contains(v)) return true;
      }
    } else if (values is AutoList<T, ST>) {
      for (var v in values._list) {
        if (_list.contains(v)) return true;
      }
    }

    return false;
  }

  @override
  void destroy() {
    clear();
  }
}
