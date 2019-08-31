class IEventHandler {
  Map<String, List<Function>> _events;

  register(String event) {
    _events[event.toLowerCase()] = [];
  }

  IEventHandler() {
    _events = {};
  }

  emitArgs(String event, List arguments) {
    event = event.toLowerCase();
    if (_events.containsKey(event)) {
      for (var i = 0; i < _events[event].length; i++) {
        if (Function.apply(_events[event][i], arguments) != null) {
          return true;
        }
      }
    }
    return false;
  }

  on(String event, Function callback) {
    event = event.toLowerCase();

    if (!_events.containsKey(event)) register(event);

    _events[event].add(callback);

    return this;
  }

  off(event, callback) {
    event = event.toString();

    if (_events.containsKey(event)) {
      if (callback != null) {
        _events[event].remove(callback);
      } else {
        this._events[event] = [];
      }
    }
  }
}
