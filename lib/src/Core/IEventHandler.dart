import 'dart:async';

import 'PropertyModificationInfo.dart';

class IEventHandler {
  final _propertyModifiedController =
      StreamController<PropertyModificationInfo>();

  Map<String, List<Function>> _events = {};

  void register(String event) {
    _events[event.toLowerCase()] = [];
  }

  IEventHandler() {}

  Stream<PropertyModificationInfo> get properyModified =>
      _propertyModifiedController.stream;

  void emitProperty(PropertyModificationInfo event) {
    _propertyModifiedController.add(event);
  }

  bool emitArgs(String event, List arguments) {
    //event = event.toLowerCase();

    var et = _events[event.toLowerCase()];
    if (et != null) {
      for (var i = 0; i < et.length; i++)
        if (Function.apply(et[i], arguments) != null) return true;
    }

    return false;
  }

  void on(String event, Function callback) {
    event = event.toLowerCase();
    if (!_events.containsKey(event)) register(event);
    _events[event]?.add(callback);
  }

  void off(String event, Function? callback) {
    event = event.toLowerCase();
    if (_events.containsKey(event)) {
      if (callback != null)
        _events[event]?.remove(callback);
      else
        this._events[event] = [];
    }
  }
}
