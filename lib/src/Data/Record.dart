import 'dart:collection';

import '../Resource/Template/TemplateDescriber.dart';

import 'IRecord.dart';
import 'KeyList.dart';

class Record extends IRecord with MapMixin<String, dynamic> {
  Map<String, dynamic> _props = Map<String, dynamic>();

  @override
  Map<String, dynamic> serialize() {
    return _props;
  }

  @override
  deserialize(Map<String, dynamic> value) {
    _props = value;
  }

  operator [](index) => _props[index];
  operator []=(String index, value) => _props[index] = value;

  @override
  String toString() {
    return _props.toString();
  }

  @override
  // TODO: implement template
  TemplateDescriber get template => throw UnimplementedError();

  @override
  void clear() {
    // TODO: implement clear
  }

  @override
  // TODO: implement keys
  Iterable<String> get keys => _props.keys;

  @override
  remove(Object? key) {
    // TODO: implement remove
    throw UnimplementedError();
  }
}
