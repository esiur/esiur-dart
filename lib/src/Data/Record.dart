import '../Resource/Template/TemplateDescriber.dart';

import 'IRecord.dart';
import 'KeyList.dart';

class Record extends KeyList with IRecord {
  Map<String, dynamic> _props;

  @override
  Map<String, dynamic> serialize() {
    return _props;
  }

  @override
  deserialize(Map<String, dynamic> value) {
    _props = value;
  }

  operator [](index) => _props[index];
  operator []=(index, value) => _props[index] = value;

  @override
  // TODO: implement template
  TemplateDescriber get template => throw UnimplementedError();
}
