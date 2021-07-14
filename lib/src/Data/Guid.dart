import 'DC.dart';

class Guid {
  DC _data;

  Guid(DC data) {
    _data = data;
  }

  DC get value => _data;

  bool operator ==(Object other) {
    if (other is Guid)
      return _data.sequenceEqual(other._data);
    else
      return false;
  }

  @override
  String toString() {
    return _data.getString(0, _data.length);
  }
}
