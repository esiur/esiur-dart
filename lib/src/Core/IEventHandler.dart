import 'dart:async';

import 'PropertyModificationInfo.dart';

class IEventHandler {
  final _propertyModifiedController =
      StreamController<PropertyModificationInfo>();

  Map<String, List<Function>> _events = {};

  register(String event) {
    _events[event.toLowerCase()] = [];
  }

  IEventHandler() {}

  Stream<PropertyModificationInfo> get properyModified =>
      _propertyModifiedController.stream;

  emitProperty(PropertyModificationInfo event) {
    _propertyModifiedController.add(event);
  }

  emitArgs(String event, List arguments) {
    //event = event.toLowerCase();

    var et = _events[event.toLowerCase()];
    if (et != null) {
      for (var i = 0; i < et.length; i++)
        if (Function.apply(et[i], arguments) != null) return true;
    }

    return false;
  }

  on(String event, Function callback) {
    event = event.toLowerCase();
    if (!_events.containsKey(event)) register(event);
    _events[event]?.add(callback);
    return this;
  }

  off(String event, callback) {
    event = event.toLowerCase();
    if (_events.containsKey(event)) {
      if (callback != null)
        _events[event]?.remove(callback);
      else
        this._events[event] = [];
    }
  }
}
