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

import '../../Data/IntType.dart';

import '../../Resource/Instance.dart';

import '../../Core/AsyncException.dart';
import '../../Core/ErrorType.dart';
import '../../Core/ExceptionCode.dart';

import '../../Resource/ResourceTrigger.dart';

import '../../Data/KeyValuePair.dart';

import '../../Resource/IResource.dart';
import '../../Core/AsyncReply.dart';
import '../../Data/PropertyValue.dart';
import '../../Data/Codec.dart';
import './DistributedConnection.dart';
import '../Packets/IIPPacketAction.dart';

import '../../Resource/Template/EventTemplate.dart';

class DistributedResource extends IResource {
  int? _instanceId;
  DistributedConnection? _connection;

  bool _attached = false;
  //bool _isReady = false;

  String? _link;
  int? _age;

  List _properties = [];
  bool _destroyed = false;

  List<KeyValuePair<int, dynamic>> _queued_updates = [];

  /// <summary>
  /// Connection responsible for the distributed resource.
  /// </summary>
  DistributedConnection? get distributedResourceConnection => _connection;

  /// <summary>
  /// Resource link
  /// </summary>
  String? get distributedResourceLink => _link;

  /// <summary>
  /// Instance Id given by the other end.
  /// </summary>
  int? get distributedResourceInstanceId => _instanceId;

  //bool get destroyed => _destroyed;

  bool get distributedResourceSuspended => _suspended;
  bool _suspended = true;

  AsyncReply<bool> trigger(ResourceTrigger trigger) => AsyncReply.ready(true);

  /// <summary>
  /// IDestructible interface.
  /// </summary>
  void destroy() {
    _destroyed = true;
    _attached = false;
    _connection?.sendDetachRequest(_instanceId as int);
    emitArgs("destroy", [this]);
  }

  void suspend() {
    _suspended = true;
    _attached = false;
  }

  /// <summary>
  /// Resource is ready when all its properties are attached.
  /// </summary>
  // bool get isReady => _isReady;

  /// <summary>
  /// Resource is attached when all its properties are received.
  /// </summary>
  bool get attached => _attached;

  // public DistributedResourceStack Stack
  //{
  //     get { return stack; }
  //}

  /// <summary>
  /// Create a new distributed resource.
  /// </summary>
  /// <param name="connection">Connection responsible for the distributed resource.</param>
  /// <param name="template">Resource template.</param>
  /// <param name="instanceId">Instance Id given by the other end.</param>
  /// <param name="age">Resource age.</param>

  // DistributedResource(
  //     DistributedConnection connection, int instanceId, int age, String link) {
  //   this._link = link;
  //   this._connection = connection;
  //   this._instanceId = instanceId;
  //   this._age = age;
  // }

  void internal_init(
      DistributedConnection connection, int instanceId, int age, String link) {
    this._link = link;
    this._connection = connection;
    this._instanceId = instanceId;
    this._age = age;
  }

  /// <summary>
  /// Export all properties with ResourceProperty attributed as bytes array.
  /// </summary>
  /// <returns></returns>
  List<PropertyValue> internal_serialize() {
    // var props = _properties as List;
    // var rt = List<PropertyValue>(_properties.length);

    // for (var i = 0; i < _properties.length; i++)
    //   rt[i] = new PropertyValue(_properties[i], instance?.getAge(i) as int,
    //       instance?.getModificationDate(i) as DateTime);

    return List<PropertyValue>.generate(
        _properties.length,
        (i) => PropertyValue(_properties[i], instance?.getAge(i) as int,
            instance?.getModificationDate(i) as DateTime));

    //return rt;
  }

  bool internal_attach(List<PropertyValue> properties) {
    if (_attached)
      return false;
    else {
      _suspended = false;

      //_properties = new List(properties.length); // object[properties.Length];

      //_events = new DistributedResourceEvent[Instance.Template.Events.Length];

      for (var i = 0; i < properties.length; i++) {
        instance?.setAge(i, properties[i].age);
        instance?.setModificationDate(i, properties[i].date);

        _properties.add(properties[i].value);
        //_properties[i] = properties[i].value;
      }

      // trigger holded events/property updates.
      //foreach (var r in afterAttachmentTriggers)
      //    r.Key.Trigger(r.Value);

      //afterAttachmentTriggers.Clear();

      _attached = true;

      if (_queued_updates.length > 0) {
        _queued_updates
            .forEach((kv) => internal_updatePropertyByIndex(kv.key, kv.value));
        _queued_updates.clear();
      }
    }
    return true;
  }

  AsyncReply<dynamic> listen(event) {
    if (_destroyed) throw new Exception("Trying to access destroyed object");
    if (_suspended) throw new Exception("Trying to access suspended object");

    EventTemplate? et = event is EventTemplate
        ? event
        : instance?.template.getEventTemplateByName(event.toString());

    if (et == null)
      return AsyncReply<dynamic>().triggerError(new AsyncException(
          ErrorType.Management, ExceptionCode.MethodNotFound.index, ""));

    if (!et.listenable)
      return AsyncReply().triggerError(new AsyncException(
          ErrorType.Management, ExceptionCode.NotListenable.index, ""));

    return _connection?.sendListenRequest(_instanceId as int, et.index)
        as AsyncReply;
  }

  AsyncReply<dynamic> unlisten(event) {
    if (_destroyed) throw new Exception("Trying to access destroyed object");
    if (_suspended) throw new Exception("Trying to access suspended object");

    EventTemplate? et = event is EventTemplate
        ? event
        : instance?.template.getEventTemplateByName(event.toString());

    if (et == null)
      return AsyncReply().triggerError(new AsyncException(
          ErrorType.Management, ExceptionCode.MethodNotFound.index, ""));

    if (!et.listenable)
      return AsyncReply().triggerError(new AsyncException(
          ErrorType.Management, ExceptionCode.NotListenable.index, ""));

    return _connection?.sendUnlistenRequest(_instanceId as int, et.index)
        as AsyncReply;
  }

  void internal_emitEventByIndex(int index, dynamic args) {
    // neglect events when the object is not yet attached
    if (!_attached) return;

    var et = instance?.template.getEventTemplateByIndex(index);
    if (et != null) {
      emitArgs(et.name, [args]);
      instance?.emitResourceEvent(null, null, et, args);
    }
  }

  AsyncReply<dynamic> internal_invoke(int index, Map<UInt8, dynamic> args) {
    if (_destroyed) throw new Exception("Trying to access destroyed object");

    if (_suspended) throw new Exception("Trying to access suspended object");
    if (instance == null) throw Exception("Object not initialized.");

    var ins = instance as Instance;

    if (index >= ins.template.functions.length)
      throw new Exception("Function index is incorrect");

    return _connection?.sendInvoke(_instanceId as int, index, args)
        as AsyncReply;
  }

  operator [](String index) {
    var pt = instance?.template.getPropertyTemplateByName(index);
    if (pt != null) return get(pt.index);
  }

  operator []=(String index, value) {
    var pt = instance?.template.getPropertyTemplateByName(index);
    if (pt != null) set(pt.index, value);
  }

  String _getMemberName(Symbol symbol) {
    var memberName = symbol.toString();
    if (memberName.endsWith("=\")"))
      return memberName.substring(8, memberName.length - 3);
    else
      return memberName.substring(8, memberName.length - 2);
  }

  @override //overring noSuchMethod
  noSuchMethod(Invocation invocation) {
    var memberName = _getMemberName(invocation.memberName);

    if (invocation.isMethod) {
      var ft = instance?.template.getFunctionTemplateByName(memberName);

      if (_attached && ft != null) {
        var args = Map<UInt8, dynamic>();

        for (var i = 0;
            i < invocation.positionalArguments.length &&
                i < ft.arguments.length;
            i++) args[UInt8(i)] = invocation.positionalArguments[i];

        for (var i = invocation.positionalArguments.length;
            i < ft.arguments.length;
            i++) {
          for (var j = 0; j < invocation.namedArguments.length; j++) {
            if (ft.arguments[i].name ==
                _getMemberName(invocation.namedArguments.keys.elementAt(j))) ;
            args[UInt8(i)] = invocation.namedArguments.values.elementAt(j);
          }
        }

        return internal_invoke(ft.index, args);
      }
    } else if (invocation.isSetter) {
      var pt = instance?.template.getPropertyTemplateByName(memberName);

      if (pt != null) {
        set(pt.index, invocation.positionalArguments[0]);
        return true;
      }
    } else if (invocation.isGetter) {
      var pt = instance?.template.getPropertyTemplateByName(memberName);

      if (pt != null) {
        return get(pt.index);
      }
    }

    return null;
  }

  /// <summary>
  /// Get a property value.
  /// </summary>
  /// <param name="index">Zero-based property index.</param>
  /// <returns>Value</returns>
  get(int index) {
    //if (_properties == null) return null;
    //var props = _properties as List;
    //if (index >= props.length) return null;
    return _properties[index];
  }

  void internal_updatePropertyByIndex(int index, dynamic value) {
    if (!_attached) {
      _queued_updates.add(KeyValuePair(index, value));
    } else {
      var pt = instance?.template.getPropertyTemplateByIndex(index);

      if (pt != null) {
        _properties[index] = value;
        instance?.emitModification(pt, value);
      }
    }
  }

  /// <summary>
  /// Set property value.
  /// </summary>
  /// <param name="index">Zero-based property index.</param>
  /// <param name="value">Value</param>
  /// <returns>Indicator when the property is set.</returns>
  AsyncReply<dynamic> set(int index, dynamic value) {
    if (index >= _properties.length)
      throw Exception("Property with index `${index}` not found.");

    var reply = new AsyncReply<dynamic>();
    var con = _connection as DistributedConnection;

    var parameters = Codec.compose(value, con);
    (con.sendRequest(IIPPacketAction.SetProperty)
          ..addUint32(_instanceId as int)
          ..addUint8(index)
          ..addDC(parameters))
        .done()
      ..then((res) {
        // not really needed, server will always send property modified,
        // this only happens if the programmer forgot to emit in property setter
        _properties[index] = value;
        reply.trigger(null);
      });

    return reply;
  }

  @override
  String toString() {
    return "DR<${instance?.template.className ?? ''}>";
  }
}
